#import "lib/common.typ": course, agentName
#import "lib/reportLib.typ": firstPage, indexPage, docBody

#firstPage(agentName)

#indexPage()

#docBody([
  = Test
  == Test2
  #figure(
    [aa],
    kind: image,
    caption: [test]
  )

  #figure(
    table(
      columns: (50%,50%),
      [],[]
    ),
    caption: [test]
  )
])