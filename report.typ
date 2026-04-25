#import "lib/common.typ": agentName, course
#import "lib/reportLib.typ": docBody, firstPage, indexPage

#firstPage(agentName)

#indexPage()

#docBody[
  = Test

  == Movement

  + if another agent is met during the movement:

    - wait x seconds and then procede

    - otherwise the other agent is stuck, so recompute astar

  + directional tiles: astar should already do the job, simply set contraints to neighbors according to the direction

  + crates: 5 indicates crate tile, 5! indicates the crate itself. compute astar, if it crosses 5!:

    - takes the direction with which 5! is approached by the path of astar, if there is 5 behind 5! the crate can be moved and the path is valid

    - otherwise temporarily replace 5! with 0 and recompute astar

  == Intention revision

  + once we have some candidate parcels around us, select:

    - the one with highest score

      - if another agent is closer, switch to the second highest-scored parcel and repeat

    - if another high parcel is close, and no agent around, pick it as well

  + once we pick up a parcel, compute a star and estimate the time needed to deliver it, then if the parcel score is sufficient to cover tha path

  + if the estimated time of a remembered parcel near the one we picked up is sufficient to cover back and forth, take it as destination

    - otherwise choose another parcel with sufficient time, if no one exists take the clsest green

  == Belief

  + measure the time spent to deliver the current parcel:



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
