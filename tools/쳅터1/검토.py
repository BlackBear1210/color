# -*- coding: utf-8 -*-
"""씬을 다시 만들지 않고 19개 도안의 색·점프 경로와 연결을 검토하고 현재 도면만 갱신한다."""
import json
from pathlib import Path

import 도안
import 도면
import 검사


def main():
    plans = 도안.모두_읽기(검사.도안폴더)
    rows = []
    for plan in plans:
        result = 검사.검사(plan, True, 출력=False, 경로_저장=True)
        # PNG는 설계 도면이다. 실제 엔진 화면과 혼동하지 않도록 결과에 경로를 따로 기록한다.
        png = Path(plan.경로).with_suffix(".png")
        도면.그리기(plan, result, str(png))
        rows.append({"이름": plan.이름, "제목": plan.제목, "실패": result["실패"], "경고": result["경고"],
                     "도안경고": plan.경고, "색비율": result["색비율"], "경로": result["경로요약"],
                     "문": result["문"], "문간": result["문간"]})
        print(plan.이름, "경로 실패", len(result["실패"]), flush=True)
    # 옆방문 존재 검사와 걷기 연결의 화면 높이는 경로 도달성과 구분해 남긴다. 알려진 전환 높이 차를 숨기지 않는다.
    connections = 검사.연결_높이_검사(plans, 출력=False)
    out = Path(검사.저장소) / "docs/visual_review/챕터1_재검토_20261010"
    out.mkdir(parents=True, exist_ok=True)
    failures = sum(len(row["실패"]) for row in rows)
    (out / "도안검토.json").write_text(json.dumps({"스테이지": rows, "경로실패": failures,
                                                 "연결검사": connections}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("경로 실패", failures, "연결 검토 항목", len(connections))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
