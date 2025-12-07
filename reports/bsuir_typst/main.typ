#include("course_title.typ")

#import "stp/stp.typ"
#show: stp.STP2024


#pagebreak()

#counter(page).update(4)

#outline()
#outline(title:none,target:label("appendix"))

#pagebreak()

#include("introduction.typ")

#include("first_section.typ")

#include("second_section.typ")

#include("third_section.typ")

#include("fourth_section.typ")

#include("fifth_section.typ")

#bibliography("bibliography.bib")

#stp.appendix(type:[обязательное], title:[Справка о проверке на заимствования], [


])


#stp.appendix(type:[обязательное], title:[Листинг программного кода], [


])

#stp.appendix(type:[обязательное], title:[Функциональная схема алгоритма,\ реализующая программное средство], [


])

#stp.appendix(type:[обязательное], title:[Блок схема алгоритма,\ реализующего программное средств], [


])

#stp.appendix(type:[обязательное], title:[Графики сравнения \ производительности процессоров], [


])

#stp.appendix(type:[обязательное], title:[Графическое представление нагрузки \ на ядра процессоров], [


])
