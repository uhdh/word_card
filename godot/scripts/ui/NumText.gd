# NumText.gd
# 숫자를 '읽는 글' 로 바꾸는 단일 출처.
#
# 왜 파일을 하나 더 두는가:
#   누적 피해가 정보창(4,200)과 런 요약(4200)에서 다르게 찍혔다. 같은 값을 두 화면이
#   다르게 쓰면, 플레이어는 두 숫자가 다른 값이라고 의심한다. 서식은 한 곳에만 있어야 한다.
#
# Palette 가 아닌 이유: Palette 는 "게임 전체의 단일 색상 소스" 라고 스스로 못 박고 있다.
#   숫자 서식을 섞으면 그 규칙이 흐려진다.
extends RefCounted
class_name NumText


## 1,240 처럼 천 단위를 끊는다.
##
## 피해량은 네 자리를 넘기면 자릿수를 눈으로 세게 된다. 요약 숫자에서 그건 읽기를 방해한다.
## (Godot 에는 천 단위 구분 서식이 없다 — String.format 도 지원하지 않는다)
static func comma(value: float) -> String:
	var rounded := roundi(value)
	var digits := str(absi(rounded))
	var out := ""
	var counted := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		counted += 1
		if counted % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if rounded < 0 else "") + out
