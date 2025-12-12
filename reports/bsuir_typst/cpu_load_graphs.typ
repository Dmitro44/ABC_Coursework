#import "stp/stp_a3.typ"
#show: stp_a3.STP_A3_2024

#let figure_appendix(letter, body, caption: none) = {
  figure(
    body,
    caption: caption,
    supplement: [Рисунок],
    numbering: (n) => letter + "." + str(n),
  )
}

#stp_a3.heading_unnumbered[Графическое представление нагрузки на ядра процессоров]

#grid(
    columns: 2,
    rows: 2,
    gutter: 1em,
    row-gutter: 4em,

    figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_single_core_smt_off.png", width: 100%),
      caption: [График нагрузки версии БПФ на одном ядре с выключенным SMT/HT]
    ),
    figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_single_core_smt_on.png", width: 100%),
      caption: [График нагрузки версии БПФ на одном ядре с включенным SMT/HT]
    ),
    figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_4cores_smt_off.png", width: 100%),
      caption: [График нагрузки версии БПФ на 4 ядрах с выключенным SMT/HT]
    ),
    figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_4cores_smt_on.png", width: 100%),
      caption: [График нагрузки версии БПФ на 4 ядрах с включенным SMT/HT]
    ),
  )

#pagebreak()

#stp_a3.heading_unnumbered[Графическое представление нагрузки на ядра процессоров]

// #grid(
//     columns: 2,
//     rows: 2,
//     gutter: 1em,
//     // align: center,
//     grid. cell(colspan: 2, align: center)[
//     #figure_appendix(
//       "Е",
//       image("plots_cpu/cpu_load_8cores_smt_off.png", width: 100%),
//       caption: [График нагрузки версии БПФ на 8 ядрах с выключенным SMT/HT]
//     )],
//     grid. cell(colspan: 2, align: center)[
//     #figure_appendix(
//       "Е",
//       image("plots_cpu/cpu_load_8cores_smt_on.png", width: 100%),
//       caption: [График нагрузки версии БПФ на 8 ядрах с включенным SMT/HT]
//     )],
// )

    #figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_8cores_smt_off.png", width: 50%),
      caption: [График нагрузки версии БПФ на 8 ядрах с выключенным SMT/HT]
    )
    #v(1em)
    #figure_appendix(
      "Е",
      image("plots_cpu/cpu_load_8cores_smt_on.png", width: 50%),
      caption: [График нагрузки версии БПФ на 8 ядрах с включенным SMT/HT]
    )
 
