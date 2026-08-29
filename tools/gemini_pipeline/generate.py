#!/usr/bin/env python3
"""나노바나나(Gemini 이미지 모델)로 텍스처 원본을 생성/편집하는 CLI.

사용 예:
    python generate.py --prompt "seamless brick wall, top-down, flat lighting, black and white only" --out out.png
    python generate.py --prompt "이 나무 텍스처를 더 거칠게" --input src/master_fill.png --out edited.png
    python generate.py --prompt "..." --out a.png b.png c.png   # 여러 장
"""

import argparse
import base64
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Windows 콘솔 기본 코드페이지(cp949)에서 한글 메시지가 깨지는 것을 막는다.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8")


def _load_env_file(path: Path) -> None:
    # google-genai 는 .env 를 자동으로 읽지 않으므로, 여기서만 수동으로 채워 넣는다.
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if key and key not in os.environ:
            os.environ[key] = value


def main() -> int:
    _load_env_file(HERE / ".env")

    parser = argparse.ArgumentParser(description="Gemini(나노바나나) 이미지 생성/편집")
    parser.add_argument("--prompt", required=True, help="생성/편집 지시문")
    parser.add_argument("--out", required=True, nargs="+", help="저장할 파일 경로 (여러 개 가능)")
    parser.add_argument(
        "--input", nargs="*", default=[], help="편집 대상으로 넣을 참고 이미지 경로 (선택)"
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image"),
        help="사용할 모델 이름 (기본: gemini-3.1-flash-image. 나노바나나 계열)",
    )
    args = parser.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print(
            "GEMINI_API_KEY 가 없다. tools/gemini_pipeline/.env.example 을 .env 로 복사하고 "
            "https://aistudio.google.com/apikey 에서 발급받은 키를 채워 넣어라.",
            file=sys.stderr,
        )
        return 1

    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)

    contents = [args.prompt]
    for img_path in args.input:
        p = Path(img_path)
        contents.append(
            types.Part.from_bytes(data=p.read_bytes(), mime_type=_guess_mime(p))
        )

    from google.genai import errors as genai_errors

    try:
        response = client.models.generate_content(model=args.model, contents=contents)
    except genai_errors.ClientError as e:
        msg = str(e)
        if "RESOURCE_EXHAUSTED" in msg or "429" in msg:
            print(
                f"[{args.model}] 할당량에 막혔다.",
                file=sys.stderr,
            )
            print("  free_tier 한도가 0 이면 무료 등급으로는 이미지 생성을 아예 못 쓴다는 뜻이다.", file=sys.stderr)
            print("  https://aistudio.google.com/billing 에서 프로젝트에 결제를 연결해야 열린다.", file=sys.stderr)
            print("  (Gemini 앱 구독 - AI Pro 등 - 은 API 할당량과 별개다.)", file=sys.stderr)
        else:
            print(f"[{args.model}] 호출 실패: {msg[:300]}", file=sys.stderr)
        return 1

    images = []
    for part in response.candidates[0].content.parts:
        if getattr(part, "inline_data", None) is not None:
            images.append(part.inline_data.data)

    if not images:
        # 텍스트만 돌아왔다면 모델이 이미지 대신 설명/거절을 낸 경우다.
        text = "".join(
            part.text for part in response.candidates[0].content.parts if getattr(part, "text", None)
        )
        print(f"이미지가 생성되지 않았다. 모델 응답: {text}", file=sys.stderr)
        return 1

    for out_path, data in zip(args.out, images):
        out = Path(out_path)
        out.parent.mkdir(parents=True, exist_ok=True)
        raw = data if isinstance(data, (bytes, bytearray)) else base64.b64decode(data)
        out.write_bytes(raw)
        print(f"저장됨: {out}")

    if len(images) > len(args.out):
        print(f"참고: 모델이 {len(images)}장을 반환했지만 --out 은 {len(args.out)}개만 지정됐다.")

    return 0


def _guess_mime(path: Path) -> str:
    ext = path.suffix.lower()
    return {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}.get(ext, "image/png")


if __name__ == "__main__":
    raise SystemExit(main())
