class_name MergeData
extends RefCounted
## 보드에 늘 보이는 **장식** 자리표시자. 게임 규칙과는 무관하다.
##
## 좌표는 보드 전체 기준 `Vector2i(행, 열)` = (row, col), 0~6.
## 참고 영상의 배치를 옮겼다 — 왼쪽·오른쪽 가운데에 꽃, 아래줄에 버섯·풀·돌, 위 오른쪽에 나무.

const PATH_DECOR := [
	{"row": 3, "col": 0, "color": "f5d24a"},  # 꽃
	{"row": 3, "col": 6, "color": "f5d24a"},  # 꽃
	{"row": 6, "col": 0, "color": "d4544e"},  # 버섯
	{"row": 6, "col": 3, "color": "6aa84f"},  # 풀
	{"row": 6, "col": 6, "color": "8a8a96"},  # 돌
	{"row": 0, "col": 4, "color": "6aa84f"},  # 풀
	{"row": 0, "col": 6, "color": "3f7a45"},  # 나무
]
