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

#stp_a3.heading_unnumbered[Графики сравнения производительности процессоров]

#grid(
    columns: 2,
    rows: 2,
    gutter: 1em,
    
    figure_appendix(
      "Д",
      image("plots/combined_comparison_single_core.png", width: 86%),
      caption: [График сравнения версии БПФ на одном ядре]
    ),
    figure_appendix(
      "Д",
      image("plots/combined_comparison_4cores.png", width: 86%),
      caption: [График сравнения версии БПФ на 4 ядрах]
    ),
    figure_appendix(
      "Д",
      image("plots/combined_comparison_8cores.png", width: 86%),
      caption: [График сравнения версии БПФ на 8 ядрах]
    ),
    figure_appendix(
      "Д",
      image("plots/igpu_comparison.png", width: 86%),
      caption: [График сравнения версии БПФ на iGPU]
    ),
  )
