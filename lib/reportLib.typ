#import "common.typ": academicYear, agentName, authors, course, date, linkColor, mainColor, university

#let firstPage(title) = {
  show link: set text(fill: linkColor)
  set document(
    title: [#title - #course - #university],
    author: (
      authors.andrea.name + " " + authors.andrea.surname + " - Student Id " + authors.andrea.stid,
      authors.matteo.name + " " + authors.matteo.surname + " - Student Id " + authors.matteo.stid,
    ),
    description: [Report for the #course course at #university],
  )
  set page(
    margin: 0em,
  )


  grid(
    columns: (35%, 65%),
    [#rect(fill: mainColor, width: 100%, height: 105%)],
    [
      #align(top + center)[
        #v(5em)
        #text(weight: "bold", size: 3em)[#course]
      ]

      // #align(center + horizon)[
      //   #text(size: 3em, weight: "bold")[#title]
      //   #v(-1em)
      //   #text(weight: "bold", size: 2em)[Report]
      //   #v(10em)
      // ]
      #align(center + horizon)[#v(-15em) #text(size: 3em, weight: "bold")[#title] #v(1em)]

      #table(
        stroke: none,
        table.vline(x: 1, start: 0, stroke: mainColor),
        columns: (45%, auto),
        align: (x, y) => {
          if (x == 0) {
            right
          } else {
            left
          }
        },
        [*Team members*], [#authors.andrea.name #authors.andrea.surname (#authors.andrea.stid)],
        [], [#authors.matteo.name #authors.matteo.surname (#authors.matteo.stid)],
      )

      #align(bottom + center)[
        #text(weight: "bold")[#university - A.Y. #academicYear]
        #v(2em)
      ]
    ],
  )
}

#let indexPage(imageList: true, tableList: true) = {
  set page(
    margin: auto,
    footer: [
      #align(center)[#context [#counter(page).display("i")]] \
      #place(dx: -71pt, dy: -2pt)[#rect(height: 50%, width: 135%, stroke: none, fill: mainColor)]
    ],
  )

  show outline.entry.where(level: 1): it => {
    v(12pt, weak: true)
    text(size: 1.2em)[*#it*]
  }

  outline(depth: 4, title: text(size: 2em)[#v(0em) Table of content #v(0.5em)])

  if (imageList == true) {
    pagebreak()

    text(size: 2em)[#v(0.5em) *Images* #v(-0.5em)]

    show outline: set text(weight: "thin")
    outline(
      title: [],
      target: figure.where(kind: image),
    )
  }

  if (tableList == true) {
    pagebreak()

    text(size: 2em)[#v(0.5em) *Tables* #v(-0.5em)]

    show outline: set text(weight: "thin")
    outline(
      title: [],
      target: figure.where(kind: table),
    )
  }
}

#let docBody(body) = {
  show figure: set block(breakable: true)
  show link: it => underline(text(fill: linkColor)[#it])
  show ref: rf => underline(text(fill: mainColor)[#rf])

  counter(page).update(1)
  set heading(numbering: "1.")

  show heading.where(level: 1): h => {
    set text(size: 1.5em)
    pagebreak()
    h
    v(1em)
  }
  show heading.where(level: 2): set text(size: 1.4em)
  show heading.where(level: 3): set text(size: 1.25em)
  show heading.where(level: 4): set text(size: 1.15em)

  set page(
    margin: auto,
    header: [

      #grid(
        columns: (33%, 33%, 33%),
        align: (x, y) => {
          if x == 0 {
            left + horizon
          } else if x == 1 {
            center + horizon
          } else {
            right + horizon
          }
        },
        [#agentName], [#course], [#date],
      )

      #line(length: 100%)


    ],
    footer: [
      #align(center)[#context [#counter(page).display("1 of 1", both: true)]] \
      #place(dx: -71pt, dy: -2pt)[#rect(height: 50%, width: 135%, stroke: none, fill: mainColor)]
    ],
  )

  body
}
