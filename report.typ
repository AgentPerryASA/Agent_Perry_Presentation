#import "lib/common.typ": agentName, course
#import "lib/reportLib.typ": docBody, firstPage, indexPage

#firstPage(agentName)

#indexPage()

#docBody[
  = Test

  == Movement

  + crates: 5 indicates crate tile, 5! indicates the crate itself. compute astar, if it crosses 5!:

    - takes the direction with which 5! is approached by the path of a\*, if there is 5 behind 5! the crate can be moved and the path is valid

    - otherwise temporarily replace 5! with 0 and recompute a\*

  == NB

  - we removed the logic to ignore other agents that are closer to out target parcel because with many agents, the ours gets stuck

  - we condensate generateIntention and selectBestIntention because it is a waste of time store all possible intentions while we put some constraints (e.g. if a GoPutDownIntention is available, no other one can be generated)

  - distance measurement are all done with a\*, we found it is particularly fast and does not slow down the intention revision

  - the possible plans are a simple goTo that goes into a new area based on weights, goPickUp, goPutDown. GoTo can be interrupted at any moment by a goPickUp. The goPickup remain fixed, after it is successful and goPutDown is chosen, a maximum of three deviation to pickup other parcels are allowed. To understand whether it is convenient, for every possible parcel a calculation is performed to understand whether the value of the new package after the agent went back to the position it was before the deviation is higher than the value of the carried parcel that at the moment had the minimum reward. This consider the travel calculated with a\* and the speed of the player, obtained from the game options. To recover the previous action, all bestIntention are pushed into a queue with their respective plans, whose context (navigation and breakpoint) are saved before the plan is stopped. No other goPickUp or GoTo can be generated until the putDown and eventual deviation are running.

  - to move in presence of a crate, a planner is used: we need to convert the map into planner files and make the planner build a plan to move all of the crates.

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
