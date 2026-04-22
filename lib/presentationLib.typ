#import "common.typ": course, authors, university, mainColor, agentName, date

#let cover(title) = {
  set document(title: [#title | #course], author: (authors.andrea.name+" "+authors.andrea.surname+" - Student Id "+authors.andrea.stid,authors.matteo.name+" "+authors.matteo.surname+" - Student Id "+authors.matteo.stid), description: [#title - Presentation for the #course project at the #university])

  set page(
    paper: "presentation-16-9",
    margin: (top: 0pt, left: 0pt, right: 0pt, bottom: 0pt),
    background: rect(fill: mainColor, width: 103%, height: 105%),
  )

  set text(fill: white)
  show grid: set text(size: 1.3em)
  align(center+horizon)[
    #text(size: 3em)[#course]
    #line(length: 80%, stroke: white)
    #text(size: 2em)[#title]
    #v(2em)
    #grid(
      grid.vline(x: 1, start: 0, stroke: white),
      columns: (30%,30%),
      align: (x,y) => {
        if(x==0) {
          right
        } else if(x==1) {
          left
        }
      },
      inset: 0.4em,
      [*#agentName team members*],
      [#authors.andrea.name #authors.andrea.surname (#authors.andrea.stid)],
      [],
      [#authors.matteo.name #authors.matteo.surname (#authors.matteo.stid)],
      []
    )
  ]

  align(bottom+center)[
    #date \ - \ University of Trento
    #v(2em)
  ]

}

#let slide(title, body) = {
  pagebreak()
  set page(
    paper: "presentation-16-9",
    margin: (top: 0pt, left: 0pt, right: 0pt, bottom: 0pt),
    background: rect(fill: white, width: 103%, height: 105%),
  )
  
  align(top)[
    #rect(fill: mainColor, width: 110%, height: 4.5em)[
      #align(horizon)[
        #h(2em) #text(fill: white, size: 2.5em)[#title]
      ]
      
    ]
  ]

  align(center+horizon)[
    #box(width: 95%, height: 76%)[#align(top+left)[#body]]
  ]

  align(bottom)[
    #show grid: set text(size: 1.1em, fill: white, weight: "medium")
    #grid(
      align: (x,y) => {
        if (x==0) {
          left
        } else if (x==1) {
          center
        } else {
          right
        }
      },
      fill: mainColor,
      stroke: mainColor,
      columns: (30%,40%,30%),
      inset: 1em,
      [#university - #date],
      [Presentation of #agentName],
      [Slide #context(counter(page).display()) of #context(counter(page).final().at(0)) ]
    )
  ]

}