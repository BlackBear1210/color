"""graphify-out/graph.json 에서 **코드 노드만** 골라 작은 HTML 그래프를 만든다.

[2026-09-17 Claude] graphify-godot 가 만든 전체 그래프(7,400 노드 · 문서 3,500 + SS2D 애드온 750 포함)는 vis-network 가
그리다가 멈춘다. 게임 코드끼리의 관계(누가 누굴 부르고 · 어느 씬이 무엇을 인스턴스하고 · 어느 스크립트를 상속하나)만
보려면 이 도구로 잘라 낸다. graphify 의 export.to_html 을 그대로 쓰므로 모양·검색·커뮤니티 필터는 원본 graph.html 과 같다.

실행:
  python tools/그래프_부분뷰.py                 # scripts + scenes  → graphify-out/graph_game.html  (게임 본체 · ~1,500 노드)
  python tools/그래프_부분뷰.py --tools         # + tools + assets  → graphify-out/graph_code.html  (빌더·검사기까지)
  python tools/그래프_부분뷰.py --focus 월드.gd --hops 2   # 한 노드 주변 N 홉만 → graphify-out/graph_focus.html
"""
import argparse
import json
from pathlib import Path

import networkx as nx
from graphify.export import to_html

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'graphify-out'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tools', action='store_true', help='tools/·assets/ 도 포함')
    ap.add_argument('--addons', action='store_true', help='addons/(SS2D) 도 포함')
    ap.add_argument('--focus', help='이 라벨(파일명·함수명)을 가진 노드 주변만')
    ap.add_argument('--hops', type=int, default=2)
    a = ap.parse_args()

    g = json.loads((OUT / 'graph.json').read_text(encoding='utf-8'))
    tops = {'scripts', 'scenes'} | ({'tools', 'assets'} if a.tools else set()) | ({'addons'} if a.addons else set())
    keep = {}
    for n in g['nodes']:
        if n.get('file_type') != 'code':
            continue
        top = (n.get('source_file') or '').split('/')[0]
        if top in tops or (a.addons and not top):
            keep[n['id']] = n
    G = nx.DiGraph() if g.get('directed') else nx.Graph()
    for nid, n in keep.items():
        G.add_node(nid, **{k: v for k, v in n.items() if k != 'id'})
    for e in g['links']:
        if e['source'] in keep and e['target'] in keep:
            G.add_edge(e['source'], e['target'], **{k: v for k, v in e.items() if k not in ('source', 'target')})
    name = 'graph_code' if a.tools else 'graph_game'
    if a.focus:
        seeds = [nid for nid, n in keep.items() if n.get('label') == a.focus or n.get('label', '').startswith(a.focus)]
        if not seeds:
            raise SystemExit(f'"{a.focus}" 라벨을 가진 코드 노드가 없다')
        near = set(seeds)
        frontier = set(seeds)
        UG = G.to_undirected(as_view=True)
        for _ in range(a.hops):
            frontier = {m for f in frontier for m in UG.neighbors(f)} - near
            near |= frontier
        G = G.subgraph(near).copy()
        name = 'graph_focus'
    # 커뮤니티는 원본 번호를 그대로 쓴다(색이 원본 graph.html 과 같아 보인다)
    communities = {}
    for nid in G.nodes:
        communities.setdefault(G.nodes[nid].get('community', 0), []).append(nid)
    labels = {cid: f'Community {cid}' for cid in communities}
    out = OUT / f'{name}.html'
    to_html(G, communities, str(out), community_labels=labels)
    print(f'{out.name}: 노드 {G.number_of_nodes()} · 선 {G.number_of_edges()} · 커뮤니티 {len(communities)}')


if __name__ == '__main__':
    main()
