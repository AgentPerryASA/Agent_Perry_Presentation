#import "lib/common.typ": agentName, course
#import "lib/reportLib.typ": docBody, firstPage, indexPage

#firstPage(agentName)

#indexPage()

#docBody[
  = Test

  == Movement

  + crates: 5 indicates crate tile, 5! indicates the crate itself. compute astar, if it crosses 5!:

    - takes the direction with which 5! is approached by the path of astar, if there is 5 behind 5! the crate can be moved and the path is valid

    - otherwise temporarily replace 5! with 0 and recompute astar

  == NB

  - we removed the logic to ignore other agents that are closer to out target parcel because with many agents, the ours gets stuck

  - we condensate generateIntention and selectBestIntention because it is a waste of time store all possible intentions while we put some contraints (e.g. if a GoPutDownIntention is available, no other one can be generated)

  == Test2
  #figure(
    [aa],
    kind: image,
    caption: [test],
  )

  #figure(
    table(
      columns: (50%, 50%),
      [], [],
    ),
    caption: [test],
  )
]
