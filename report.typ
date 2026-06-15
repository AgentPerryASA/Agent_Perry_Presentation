#import "lib/common.typ": agentName, course
#import "lib/reportLib.typ": docBody, firstPage, indexPage

#firstPage(agentName)

#indexPage()

#let Astar = $A^*$

#docBody[

  = BDI agent

  The BDI agent is composed by a class dedicated to manage its beliefs, a set of classes to define the intentions and plans, and the actual `bdi_agent.js` that implements the beliefs set up and update, intention revision, intention storage and plan execution.

  == Beliefs <sec-beliefs>

  In order to carry the various activity, the agent keeps track of various elements that it can understand from the environment inside an instance of the *Beliefs* class that can be located in the *`belief.js`* file. In this document the most relevant one will be reported.

  Firstly, the agent memorize some information about itself inside an instance of the *Me* class inside the belief: specifically its *id*, *name*, current *score* and *penalty*, its current *coordinates* and map of *carried parcels*, the id of an additional agent *mateId* and the one of the agent that is attached to the LLM component *llmId* (see @sec-llm) and, finally, the time that the agent wait before trying another movement, *agentMovementDelay*.

  Secondly, the agent also keeps an internal reference to an instance of *PathFinder*, which is the class containing the #Astar algorithm used to calculate the path between two tiles and capabilities to invoke the planner (see @sec-planner): this is initialized inside the *`updateTileMap()`* function, which is responsible to update the map used by pathFinder but also to call *`updatePathsWeights()`*, a function that set up all possible path from a green tile to a red tile and vice versa and assign a weight between 0 (impossible to take) and 1 (certainly the next path) with the *`updatePathsWeight()`* function. This mechanism is later used during the intention revision phase, specifically for a *GoToIntention* or a *GoPutDownIntention* to prevent choosing always the same path. For additional information about these two intention, see @sec-intentions.

  An important part for the beliefs is the list of detected parcels, *parcelList*: this is updated using the *reviseParcelList(sensedParcelsList)* function and it is not a simple memorization mechanism. Upon receiving a new list of sensed parcels, the function predicts the time it will need for it to complete the revision, fixed ad 0.01 seconds per parcel currently present in the list. Why this time, called *endTime*, whose value has been chosen after several tries, is important will be explained later. \
  For every parcel that was already memorized, it is first checked whether the same parcel in the sensed list is carried by the current agent: in case of positive answer, the carried parcels map is updated. Otherwise, the function checks whether the parcel is not carried, has a score over a minimum value (*parcelMinScore*) and is over a green tile (this is to avoid that the agent put down and sequentially pick up the same parcel when it is teaming up with another agent, see @sec-coordination for additional information): in such case the parcel information are updated, including the endTime, otherwise the parcel is deleted from the list.

  If a parcel of the list is not present in the sensed list, this means that is necessary to update its current value manually: to do that, every parcel in the list has a field called *cumulatedTime* that stores how much time passed after every execution of the revision function. This field is equal to its current value, plus the difference between the endTime (time after the revision function finish its execution) and the time in which the parcel was updated for the last time (*lastUpdateTimestamp*). If the new cumulatedTime is higher than the decay timer value (*parcelDecayTimerValue*), then its reward is updated accordingly to the cumulatedTime divided by the decay value. Of course, if the new reward is under the minimum accepted value, the parcel is automatically deleted.

  Finally, all parcels that were not previously on the list are added to the parcelList.

  The agent also keeps track of near detected agent and the total number of encountered agents (*encounteredAgentsIdList*) with the function *`updateNearAgentList(agents)`*: only the currently visible agents are memorized, and this information is used during agent movement. Specifically, when the agent is moving, it constantly checks this map to see whether an agent is in a tile that it will use in the near future. If that is the case, a deviation is started to be calculated in such a way that when the agent will be near the detected agent, it will take the deviation, avoiding a collision with the other agent.

  Finally, the Beliefs class also offers method to automatically generate the information needed for the planner (see @sec-planner) and the LLM for the parameters tuning functionality (see @sec-llm). Regarding the first case, the agent memorized a map of all encountered crate, *tileWithCrateMap*: unfortunately, information about the crates position are not available upon agent spawn, therefore, this map is populated as the agent roam through the map.

  == Intentions <sec-intentions>

  We defined the following types of intentions that the agent can create according to its beliefs.

  - *GoToIntention* - the desire of reaching a specific tile.

  - *DeviateUsingAStarIntention* - the desire of requesting to the internal #Astar algorithm a new path, because the one selected by the agent is no more practicable.

  - *DeviateUsingPlannerIntention* - the desire of requesting to the planner a new path, because the one selected by the agent is no more practicable. The planner involvement is explained in details in @sec-planner.

  - *GoPickUpIntention* - the desire of picking up a parcel at a specific tile.

  - *GoPutDownIntention* - the desire of delivering all the parcel the agent is carrying on a specific red tile.

  - *DeviateAndPickUpIntention* - the desire of picking up a parcel while the agent is going to put down others. In some cases the agent can pick up a parcel that will increase the score with a simple small change in the path, without wasting much time.

  Besides BDI agent intentions, generated by the agent itself, also the LLM agent (explained in details in @sec-llm), can provide the following new intentions.

  - *LLMGoToIntention*

  - *LLMGoPutDownIntention*

  - *LLMGreenRedLightIntention*

  A *`intentionPlanQueue`* queue is defined in order to store the pairs of selected intentions and the corresponding plans. The first element of the queue is executed by the agent.

  === Intention revision

  After the beliefs are set, an interval of 100 milliseconds generates a new intention, the best one at that moment according to the agent beliefs. Thus, for each intention, a proper intention revision is defined taking into account also the priority of each of them. Indeed, once some conditions are satisfied for a certain intention, this si return as the best one and the intention revision is interrupted. Therefore, the `selectBestIntention()` function is structured as follows.

  + If the LLM agent provided a *LLMGreenRedLightIntention*, this takes the maximum priority because it belongs to the level 3 tasks, and so it should give a very large reward.

  + If the LLM agent supplied a *LLMGoToIntention*, the agent evaluates the convenience of the deviation. If the agent discards the LLM intention, it forwards it to the other agent (the coordination is explained in details in @sec-coordination)

  + If the agent is achieving a GoPutDownIntention, check if, not so far from the current path, a parcel with a relevant score exists. If so, estimate the values of the lower carried parcel and of the target parcel at the time the pick up should be executed. If at that time the target parcel will have a higher score that the carried one, going to pick it up is convenient and *DeviateAndPickUpIntention* is returned. Note that our agent moves very fast so the estimated difference is negligible, but we decided to implement it anyway as a proper way of working.

  + If the agent has just picked up a parcel, select a random red tile from the pre-computed weighted paths (refer to @sec-beliefs) of the green tile (from which the agent just picked up the parcel), and return *GoPutDownIntention*.
  Notice that the defined GoPutDownIntention is not necessarily the one that will be executed: in fact, during the normal execution of the agent, the LLM component could ask to modify an already existing GoPutDownIntention. For obvious reasons, before apply the change, a revision is performed using the *`reviseLLMGoPutDownIntention()`* function, which check whether the cumulated value of the currently carried parcels (if present) is less than the same value updated with the reward suggested by the LLM.

  + If the agent is not carrying any parcel, select the parcel with the highest score, greater than the minimum acceptable, among all those the agent remembers and sees (if any). Then, return *GoPickUpIntention*.

  + If neither a GoPickUpIntention nor a GoPutDownIntention is in the queue, select a radom green tile and return *GoToIntention* (either from the pre-computed weighted paths of the red tiles the agent just delivered on, or just `Math.random()` among all green tiles).

  Finally, if the selected best intention is not already present in the queue, the current intention is stopped and the new intention is pushed together with the corresponding plan. If the current intention was a GoToIntention, it is also popped due to its lowest priority. Then, the (new) current plan is executed and popped once it finishes. If the completed plan was a deviation and the current one is a GoPutDownPlan, the path of latter is updated keeping the same destination but with a new start point, the tile on which there was the parcel that caused the deviation.

  == Plans

  We decided to split the plans into basics actions, and then combine them in order to build more complex plans. The fundamental steps are the following.

  - *GoToPlan* - calculates a path from the agent position to a specified tile. According to the situation, it can use either an internal algorithm (#Astar in our case) or the planner. Once the path is computed, at each step the next tiles in front of the agent are checked to detect any obstacle (e.g. another agent or a crate). In order to avoid collisions and accumulate penalties, a deviation is computed in advance from the tile immediately before the obstacle. The tile of the obstacle is temporarily obscured (type 0) such that the path finder algorithm ignores it (as explained in @sec-beliefs).

  - *DeviateUsingAStarPlan* - calculates a path from a certain tile to a specified destination using the #Astar algorithm. It is used as a sub-plan in GoToPlan.

  - *DeviateUsingPlannerPlan* - calculates a path from a certain tile to the next non-yellow tile in the current path using the planner. It is used as a sub-plan in GoToPlan when the agent runs into a crate. See @sec-planner for more information.

  - *GoPickUpPlan* - instantiates a GoToIntention and a GoToPlan as sub-intention and sub-plan to reach a parcel, then performs an `emitPickp()`.

  - *GoPutDownPlan* - similar to GoPickUpPlan but performs an `emitPutdown()` at the end.

  - *DeviateAndPickUpPlan* - uses GoPickUpPlan as sub-plan, and in addition it adopts #Astar to compute in advance the path from the parcel to the actual destination.

  - *LLMGreenRedLightPlan* - masks the set of tiles allowed by the prompt (e.g. only odd-numbered rows) and instantiates a GoToPlan to reach the closest available tile.

  Each plan contains an `isApplicable(intention)` function used by the agent to verify which plan can handle which intention, then an `execute(intention)` method that actually performs the plan. This constantly checks if the agent requested to stop the plan (because the current intention changed): the `isStopped` variable is set to true, but the agent has to wait that also `isRunning` is set to false, namely the plan actually stopped. Since a check cannot be performed at every frame, a bit of delay is inevitable.

  = Planner <sec-planner>

  One of the requirements for the project was to extend the agent by using the PDDL planner.

  #agentName uses the planner in order to successfully travel through paths that have a crate between them.

  As described in @sec-beliefs, the agent memorize crate position while it roams through the map: during movement, when trying to execute the next step, the agent check whether the next tile would be a yellow tile with a crate on it. If that represents the current situation, the agent stop and invoke the planner in order to find a solution that allow, also with moving the crate if necessary, to proceed until the next tile in the path that is not yellow. In other words, when the path is blocked due to the presence of a crate, the planner is used to find how to move the crate in order to go over the various yellow tiles.

  Regarding the predicates used, these are specified in the domain for the planner which can be found in the *`domain.pddl`* folder. Specifically, for every tile of the map, the domain offers predicates to specify its position with respect to its neighbors (therefore, over, under, on the right and/or on the left of another tile). Additionally, the predicates allow to specify whether the tile is currently the one with #agentName over it and if the tile has a crate over it.

  Unfortunately, due to limitation of the planner, it is not possible to express negative conditions in the preconditions of an action: for this reason, and additional predicate has been inserted in order to specify the tile that are walkable (therefore, without any crate).

  The possible actions the planner can suggest are to move up, down, left or right, with appropriate variation to include the possibility that upon moving the crate will move to the respective direction (for example, it is not possible to perform a normal *`MoveUp`* action if the current tile is under a tile with a crate, the action *`MoveCrateUp`* should be executed instead, since it also allow the planner to keep track of the new position of the crate).

  Regarding the problem for the PDDL, this is automatically generated by the beliefs of the agent through the *`getBeliefForPlanner()`* function: specifically, this includes the position of every tile with respect to its neighbors (obviously without considering non-walkable tiles), the tile in which #agentName is, the tiles that have a crate on it according to the current beliefs of the agent and the tiles the agent thinks are without any crate over it.

  The planner is exclusively used when a DeviateUsingPlannerPlan is executed: this plan will recover the domain file, prepare the problem file as described, and then it invokes the PDDL planner api through the PathFinder instance. Upon receiving the result, it prepares the set of steps and memorize them into an internal variable, making possible for the original caller, most probably a GoToPlan, to recover the new path to follow.

  = LLM <sec-llm>

  == BDI agents coordination <sec-coordination>
]
