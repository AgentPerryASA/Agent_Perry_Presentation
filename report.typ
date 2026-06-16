#import "lib/common.typ": agentName, course
#import "lib/reportLib.typ": docBody, firstPage, indexPage

#import "@preview/chronos:0.3.0"

#firstPage(agentName)

#indexPage(tableList: false)

#let Astar = $A^*$

#docBody[
  = BDI agent

  The BDI agent is composed by a class dedicated to manage its beliefs, a set of classes to define the intentions and plans, and the actual `bdi_agent.js` that implements the beliefs set up and update, intention revision, intention storage and plan execution.

  == Beliefs <sec-beliefs>

  In order to carry the various activities, the agent keeps track of many elements that it can understand from the environment inside an instance of the `Beliefs` class, that is located in the `belief.js` file. In this section the most relevant one will be reported.

  Firstly, the agent memorizes some information about itself inside an instance of the `Me` class inside the belief: specifically its *ID*, *name*, current *score* and *penalty*, the set of *carried parcels*; in addition, the ID of another eventual agent `mateId`, and the ID of the agent that is attached to the LLM component `llmId` (see @sec-llm). Finally, the time that the agent wait before trying another movement, `agentMovementDelay`.

  Secondly, the agent also keeps an internal reference to an instance of `PathFinder`, which is the class containing both the #Astar algorithm used to calculate the path between two tiles and capabilities to invoke the planner (see @sec-planner): this is initialized inside the `updateTileMap()` function, which is responsible to update the map used by `pathFinder`, but also to call `updatePathsWeights()`, a function that sets up all possible path from a green tile to a red tile and vice versa and assigns a weight between 0 (impossible to take) and 1 (certainly the next path). This mechanism is later used during the intention revision phase, specifically for the GoToIntention or a GoPutDownIntention to prevent choosing always the same path. For additional information about these two intentions, see @sec-intentions.

  The two functions adopted to weight the paths and so randomize the destination (green or red tile) are the following, also represented in @fig-rnd-func-graphs respectively.

  - *Cosine* - $cos(1.5 dot x)$, used to favor exploration. It decreases slowly as the distance grows, so even far tiles have a decent probability to get chosen.

  - *Hyperbola* - $0.1 / (x + 0.1)$, used to privilege close tiles. It rapidly decreases as the distance grows.

  Note that the domain of the functions is $[0, 1]$. Given a red or green tile, every distance of every its path is normalized over the sum of all distances. Hence, given the set of path $P = {p_1, dots, p_n}$ and the respective distances $D = {d_1, dots, d_n}$, firstly the ratio of each path is calculated as $r_i = d_i / (sum_(j=0)^n d_j)$, and then the weight $w_i = f(r_i)$.

  #figure(
    image(
      "img/rnd-func-graphs.png",
      width: 50%,
    ),
    caption: [Graphs of cosine and hyperbola style functions],
  ) <fig-rnd-func-graphs>

  In the case of two "special" tiles only, so $n = 1$ for both of them, the weight would be the lowest possible because of the maximum ratio $r_1 = 1$, so a condition is set to override the value to $w_1 = 1$.

  Moreover, some death areas might be found in the maps, in particular leveraging the directional tiles that allow the agent to enter but not to exit. To avoid them, once the paths are pre-computed for each red and green tile, the forth and back route is considered: if both the paths are found, they are stored and weighted, otherwise they will not be selected from the random function when needed, and so the "one-way" zone will ever be reached.

  An important part for the beliefs is the list of detected parcels, `parcelList`: this is updated using the `reviseParcelList(sensedParcelsList)` function and it is not a simple memorization mechanism. Upon receiving a new list of sensed parcels, the function predicts the time it will need for it to complete the revision, fixed at 0.01 seconds per parcel currently present in the list. Why this time, called `endTime`, whose value has been chosen after several tries, is important will be explained later.

  For every parcel that was already memorized, it is first checked whether the same parcel in the sensed list is carried by the current agent: in case of positive answer, the carried parcels list is updated. Otherwise, the function checks whether the parcel is not carried, has a score over a minimum value `parcelMinScore`, and is over a green tile (this is to avoid that the agent put down and sequentially pick up the same parcel when it is teaming up with another agent, see @sec-coordination for additional information): in such case the parcel information are updated, including the endTime, otherwise the parcel is deleted from the list.

  If a parcel of the list is not present in the sensed list, this means that is necessary to update its current value manually: to do that, every parcel in the list has a field called `cumulatedTime` that stores how much time passed after every execution of the revision function. This field is equal to its current value, plus the difference between the endTime (time after the revision function finishes its execution) and the time in which the parcel was updated for the last time (`lastUpdateTimestamp`). If the new cumulatedTime is higher than the decay timer value (`parcelDecayTimerValue`), then its reward is updated accordingly to the `cumulatedTime` divided by the decay value. Of course, if the new reward is under the minimum acceptable value, the parcel is automatically deleted.

  Finally, all parcels that were not previously on the list are added to `parcelList`.

  The agent also keeps track of near detected agents and the total number of encountered agents (`encounteredAgentsIdList`) with the function `updateNearAgentList(agents)`: only the currently visible agents are memorized, and this information is used during agent movement. Specifically, when the agent is moving, it constantly checks this list to see whether an agent is in a tile that it will use in the near future. If that is the case, a deviation is started to be calculated in such a way that when the agent will be near the detected agent, it will take the deviation, avoiding a collision with the other agent.

  Finally, the `Beliefs` class also offers methods to automatically generate the information needed for the planner (see @sec-planner) and the LLM for the parameters tuning functionality (see @sec-llm). Regarding the first case, the agent memorizes a list of all encountered crates, `tileWithCrateMap`: unfortunately, information about the crates position are not available upon agent spawn, therefore, this map is populated as the agent roams through the map.

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

  A `intentionPlanQueue` queue is defined in order to store the pairs of selected intentions and the corresponding plans. The first element of the queue is executed by the agent.

  === Intention revision

  After the beliefs are set, an interval of 100 milliseconds generates a new intention, the best one at that moment according to the agent beliefs. Thus, for each intention, a proper intention revision is defined taking into account also the priority of each of them. Indeed, once some conditions are satisfied for a certain intention, this si return as the best one and the intention revision is interrupted. Therefore, the `selectBestIntention()` function is structured as follows.

  + If the LLM agent provided a *LLMGreenRedLightIntention*, this takes the maximum priority because it belongs to the level 3 tasks, and so it should give a very large reward.

  + If the LLM agent supplied a *LLMGoToIntention*, the agent evaluates the convenience of the deviation. If the agent discards the LLM intention, it forwards it to the other agent (the coordination is explained in details in @sec-coordination)

  + If the agent is achieving a GoPutDownIntention, check if, not so far from the current path, a parcel with a relevant score exists. If so, estimate the values of the lower carried parcel and of the target parcel at the time the pick up should be executed. If at that time the target parcel will have a higher score that the carried one, going to pick it up is convenient and *DeviateAndPickUpIntention* is returned. Note that our agent moves very fast so the estimated difference is negligible, but we decided to implement it anyway as a proper way of working.

  + If the agent has just picked up a parcel, select a random red tile from the pre-computed weighted paths (refer to @sec-beliefs) of the green tile (from which the agent just picked up the parcel), and return *GoPutDownIntention*.
  Notice that the defined GoPutDownIntention is not necessarily the one that will be executed: in fact, during the normal execution of the agent, the LLM component could ask to modify an already existing GoPutDownIntention. For obvious reasons, before apply the change, a revision is performed using the `reviseLLMGoPutDownIntention()` function, which check whether the cumulated value of the currently carried parcels (if present) is less than the same value updated with the reward suggested by the LLM.

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

  One of the requirements for the project was to extend the agent by using the PDDL planner. #agentName uses the planner in order to successfully travel through paths that have crates between them.

  As described in @sec-beliefs, the agent memorizes crates position while it roams through the map: during movement, when trying to execute the next step, the agent checks whether the next tile would be a yellow tile with a crate on it. If that represents the current situation, the agent stops and invokes the planner in order to find a solution that allows, also with moving the crate if necessary, to proceed until the next tile in the path that is not yellow. In other words, when the path is blocked due to the presence of a crate, the planner is used to find how to move the crate in order to go over the various yellow tiles.

  #figure(
    image(
      "img/planner-example.png",
      width: 45%,
    ),
    caption: [Example of deviation using the Planner],
  )

  Regarding the predicates used, these are specified in the domain for the planner, which can be found in the `domain.pddl` file. Specifically, for every tile of the map, the domain offers predicates to specify its position with respect to its neighbors (i.e. over, under, on the right and/or on the left of another tile). Additionally, the predicates allow to specify whether the tile is currently the one with #agentName over it and if the tile has a crate over it.

  Unfortunately, due to limitations of the planner, it is not possible to express negative conditions in the preconditions of an action: for this reason, an additional predicate has been inserted in order to specify the tile that are walkable, namely without any crate.

  The possible actions the planner can suggest are to move up, down, left or right, with appropriate variations to include the possibility that, upon moving the crate, will move to the respective direction. For example, it is not possible to perform a normal `MoveUp` action if the current tile is under a tile with a crate; the action `MoveCrateUp` should be executed instead, since it also allows the planner to keep track of the new position of the crate.

  Regarding the problem for the PDDL, this is automatically generated by the beliefs of the agent through the `getBeliefForPlanner()` function: specifically, this includes the position of every tile with respect to its neighbors (obviously without considering non-walkable tiles), the tile in which #agentName is, the tiles that have a crate on it according to the current beliefs of the agent, and the tiles the agent thinks are without any crate over it.

  The planner is exclusively used when a DeviateUsingPlannerPlan is executed: this plan will recover the domain file, prepare the problem file as described, and then it invokes the PDDL planner API through the `PathFinder` instance. Upon receiving the result, it prepares the set of steps and memorizes them into an internal variable, making possible for the original caller, GoToPlan in our implementation, to recover the new path to follow.

  = LLM <sec-llm>

  While the main goal of an agent in Deliveroo.js is to gain as much points as possible, the admin user can issue some tasks that allow agents to get additional points. Specifically, the agent supports the following commands, divided by level.

  - *Level 1*:
    - The agent is able to go to a specified coordinate to get additional points;
    - The agent is able to deliver parcels to a defined red tile if this allows it to get more points;
    - The agent is able to answer questions like "Calculate log(100)", "What is the temperature in Rome?", "What are the coordinates of Rome?", or "What is the year reported in the following website?";
  - *Level 2*:
    - The agent is able to modify the number of parcels it can collect before delivering them if an exact amount allows it to gain more points;
    - The agent is able to privilege some red tiles rather than another when they make the agent gain more points;
  - *Level 3*:
    - The agent is able to team up with another agent to deliver a parcel. Specifically, the first agent could drop a set of parcels in a certain location and tell the other agent to pick them up and deliver them if such action will allow to get more points;
    - The agent is able to stop onto a given coordinate, or onto an even or odd-numbered row or column until it is told to move again if such action allows to gain more points.

  When the admin publishes a task, one of the two agents question the LLM about what is the best intention, and then it will follow the LLM's answer.

  Unfortunately, to make the LLM understand what action is the more appropriate one, an initial introduction prompt is necessary: because of hallucination-related issues with the LLM, it was not possible to support all the tasks published on the course's slides.

  In order to satisfy the tasks, the following tools have been introduced inside the `llm-tools.js` file.

  - *calc* - evaluate a mathematical expression;

  - *findExtremePosition* - returns a red tile in an extremes of the map (leftmost, rightmost, topmost or bottommost);

  - *webSearch* - retrieves a webpage and makes the LLM analyze it in order for it to found some required information;

  - *getLatLong* - returns the latitude and longitude of a certain location;

  - *getTemp* - return the current temperature in a certain location.

  About the architecture, the LLM component is not integrated with the BDI agent, but it has to be considered as a plugin to the BDI agent. Specifically, when the LLM functionality is enabled inside the `.env` file (setup instruction of the agent can be retrieved at the #link("https://github.com/AgentPerryASA/Agent_Perry")[project repository]), an instance of an `LLMAgent` is created and connected to the Deliveroo.js server via the same token of one of the two agents (specifically, the one with token TOKEN1 in the `.env` file). Since the nature of the various tasks, another agent need to be spawn upon startup of the main script: the two agent proceed to connect to each other via a handshake protocol that works as shown in the @handshakeProtocol.

  #figure(
    caption: [Handshake protocol between agents],
  )[
    #align(horizon + center)[
      #chronos.diagram({
        import chronos: *

        _par("A2", display-name: "Second Agent")
        _par("A1", display-name: "First Agent")
        _par("LLM", display-name: "LLMAgent")

        _seq("LLM", "LLM", comment: "Register attached agent identifier", comment-align: "center")
        _seq("A1", "A2", comment: "HandshakeMessage{key: dotEnvKey, agentId: id}", comment-align: "center")
        _seq("A2", "A2", comment: "Register mate identifier", comment-align: "center")
        _seq("A2", "A1", comment: "HandshakeMessage{key: dotEnvKey, agentId: id}}", comment-align: "center")
        _seq("A2", "LLM", comment: "HandshakeMessage{key: dotEnvKey, agentId: id}}", comment-align: "left")
        _seq("A1", "A1", comment: "Register mate identifier", comment-align: "center")
        _seq("LLM", "LLM", comment: "Register agent identifier", comment-align: "center")

        _seq("LLM", "A1", comment: "LLMSetIdMessage{llmAgentId: id}", comment-align: "center")
        _seq("A1", "A1", comment: "Register agent with LLM identifier", comment-align: "center")

        _seq("LLM", "A2", comment: "LLMSetIdMessage{llmAgentId: id}", comment-align: "center")
        _seq("A2", "A2", comment: "Register agent with LLM identifier", comment-align: "center")
      })
    ]
  ] #label("handshakeProtocol")

  The `LLMAgent` is constantly listening to messages published by the admin user: upon reception, the message is analyzed by the LLM connected to the agent, which elaborate a final decision to send to the connected `BDIAgent` or both the agent.

  - If the task requires to move an agent to a certain tile, an *LLMGoToIntention* is sent to the attached agent for making it move to a certain tile.

  - If the task requires to drop a parcel in a specific location, a *LLMGoPutDownIntention* is sent to the attached agent to modified a GoPutDownIntention delivery location, if such intention was present in the queue.

  - If the task requires to privilege (or disadvantage) delivering to a certain group of tiles an *LLMSetTileWeightMultiplierMessage* is sent to both agents in order to positively or negatively impact the weight of such group of tiles.

  - If the task requires to stop in an odd or even row/column tile a *LLMGreenRedLightIntention* is sent. When the admin tell that movement can resume, a *LLMGreenLightEmittedMessage* is sent. Both messages are sent to both agents.

  - If the task requires to answer directly (for example, because the temperature was asked), the `LLMAgent` will directly answer without contacting anyone.

  Finally, the LLM automatically filters out tasks with a negative revenue (except if such task requires to deprioritize a red tile) and it is used also to tune some parameters, see @sec-tuning for additional information.

  == BDI agents coordination and task revision <sec-coordination>

  Upon receiving an intention, while LLMIntentions usually take priority over other intentions, this does not mean they will necessarily executed, since a revision always takes place.

  Specifically, a deviation caused by a LLMGoToIntention is taken only if it is at a maximum of 3 tiles from the agent or if the number of points that the agent would gain is greater that the value the same agent will obtain by delivering the currently carried parcels.

  Similarly, an LLMGoPutDownIntention is taken into consideration if the agent had already a GoPutDownIntention in the queue and if by changing the delivery point the number of points that it will get is greater than the value obtained by simply delivering the current parcels.

  In both cases, if the intention cannot be taken into consideration, the same intention is forwarded to the agent who completed the handshake protocol with the agent attached to the LLM: this behavior define the simplest collaboration strategy between the two agents. However, it is perfectly possible for an agent to be required to put down the currently carried parcels in a non-red tile: to avoid losing point, the agent will send a message to the other agent asking it to pick up the dropped parcels. This intention, called *LLMGoPickUpIntention*, has maximum priority and it is never dropped since it usually originates because the LLM asked the two agents to team up in a delivery.

  Finally, it is important to mention that if an agent decides to execute a LLMIntention, this assumes maximum priority: it is not possible to stop the execution of such intention. This was decided based on the general nature of the various tasks, an opportunity to gain a considerable amount of points.

  == BDI agents parameters tuning <sec-tuning>

  A LLM is a very powerful tool that is able to understand concepts, reason on them and provide some consistent answers. We desired to leverage these properties not only by interpreting tasks, but also evaluating the performances of the BDI agents and tuning their parameters. For this purpose, each agent supply the following data to the LLM agent every 30 seconds.

  - Score of the agent.

  - Maximum number of parcels that can spawn in the map. This information might help the LLM to ponder about random functions (whether favor exploration) and the number of deviations.

  - Average score per parcel.

  #let avg = text[avg]
  #let var = text[var]
  - Variance score per parcel (the final score is a random value in $[#avg - #var, #avg + #var]$).

  - Number of agents seen so far. If there are many agents in the map, the movement speed should decrease in order to reduce collisions, and probably the number of deviations is diminished in turn due to high competition.

  - Mean of attempts to follow a path. For every computed path $p_i$, a set of deviations $d_i$ due to some obstacles might be taken. The mean is thus calculated as $m = 1/k sum_(i=1)^k abs(d_i)$ where $k$ is the number of taken paths. Having a low $m$ means successfully avoiding obstacles.

  - Types of functions to select random destination tiles (used to explore the map).

  The LLM is required to provide the new values for the following parameters.

  - Number of possible deviations to pick up a parcel (between 2 and 5).

  - Number of tiles in front of the agent to check an obstacle on the path (between 2 and 4).

  - Number of tiles to ignore after an obstacle on the path (between 2 and 4).

  - Delay in sending movement requests to the server (between 0 and 100 ms).

  - Type of function to randomize the destination ("cosine" for higher randomicity, "hyperbola" for privileging close tiles).

  - Multiplier $m$ to get $#text[parcelMinScore] = #text[parcelMaxScore] dot m$ (between 0.2 and 0.6).

  Once the LLM responds, the LLM agent parses the values, verifies they are in the requested ranges, and sends back a *LLMParametersTuningResponseMessage*. The receiver BDI agent assigns the new values in its beliefs and smoothly continue to play.

  // - *LLMSetAdditionalTuningParametersMessage*
]


