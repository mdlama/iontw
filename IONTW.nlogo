globals
[ 
  click?   ; flag indicates mouse-down has been handled
  init?    ; initialization has occurred
  checked? ; flag for checking proper simulation parameters
  node-labels   ; toggle for node labels (not a true/false)
  infectious-color    ;; red
  removed-color   ;; green (used to be gray-2)
  susceptible-color ;; white (used to be green)
  latent-color      ;; blue
  removed-link-color
  infectious-link-color
  turtle-head   ;; for manual linking
  distribution
  conncomp
  max-infected
  nbins
  lose-immunity-rate
  lose-immunity-prob
]

turtles-own
[
  infectious?           ;; if true, the turtle is infectious
  removed?          ;; if true, the turtle can't be infectious
  latent?             ;; if true, the turtle is infected but not infectious
  susceptible?        ;; if true, the turtle is susceptible
  init-infectious?
  init-removed?
  init-latent?
  init-susceptible?
  degree
  clustering
  shortest-path
  unvisited   ;; Useful for Dijkstra algorithm
  dist        ;; Useful for Dijkstra algorithm
]

to startup
  ; Note:  This may not be needed in BehaviorSpace.  The only thing that might be effected is init? and max-infected
  set latent-color yellow - 1
  set infectious-color red
  set removed-color gray - 1
  set susceptible-color green
  set removed-link-color gray - 2
  set infectious-link-color red + 1
  set turtle-head nobody
  set distribution []
  set node-labels 0
  set max-infected []
  set click? false
  set init? false
  set checked? false
  set-default-shape turtles "circle"
  set nbins 10
end

to set-defaults
  set network-type "Complete Graph"
  set num-nodes 120
  set lambda 5
  set time-step 0.02
  set set-state-to "Infectious"
  set set-state-by "Number of nodes"
  set plot-metric "Degree Distribution"
  set spawn-kill "Spawn"
  set num/frac 1
  set min-deg 0
  set gain-immunity true
  set latent-period false
  set lose-immunity-rate 0
  set end-infection-rate 1
  set end-latency-rate 0
  set infection-rate 1.4 
  set infection-prob 1 - exp(-1 * infection-rate * time-step)
  set end-infection-prob 1 - exp(-1 * end-infection-rate * time-step)
  set lose-immunity-prob 1 - exp(-1 * lose-immunity-rate * time-step)  
  set end-latency-prob 1 - exp(-1 * end-latency-rate * time-step)  
  set model-time "Discrete"
  set d 0.6
  set auto-set false
end

to clean
  clear-turtles
  clear-links
  reset-ticks
  set-current-plot "Disease Prevalence"
  clear-plot
  set-current-plot "Network Metrics"
  if (plot-metric = "Degree Distribution") [
    clear-plot
  ]
  set max-infected []
end

to new-network
  clean
  if (num-nodes < 1 or (num-nodes mod 1) != 0) [
    user-message "Number of nodes must be a positive integer."
    stop
  ]
  if (num-nodes > 0) [
    if (network-type = "Complete Graph")
    [
      let nodes setup-nodes num-nodes
      setup-complete-graph
    ]
    if (network-type = "Empty Graph")
    [
      let nodes setup-nodes num-nodes
      layout-circle turtles 0.95 * max-pxcor
    ]
    if (network-type = "Erdos-Renyi")
    [  
      let nodes setup-nodes num-nodes
      setup-erdos-renyi
      layout-circle turtles (max-pxcor - 1)
    ]
    if (network-type = "Nearest-neighbor 1")
    [
      let nodes setup-nodes num-nodes
      setup-nne1
    ]
    if (network-type = "Nearest-neighbor 2")
    [
      setup-nne2
    ]
    if (network-type = "Small World 1")
    [
      setup-small-world-er 1
    ]
    if (network-type = "Small World 2")
    [
      setup-small-world-er 2
    ]
    if (network-type = "Preferential Attachment")
    [
      setup-pref-attach
    ]
    if (network-type = "Generic Scale-free")
    [
      setup-generic-scale-free
    ]
    if (network-type = "Spatially Clustered")
    [
      let nodes setup-nodes num-nodes  
      setup-spatially-clustered-network
    ]
    if (network-type = "Random Regular")
    [
      let nodes setup-nodes num-nodes
      setup-random-regular
    ]
    if (network-type = "Regular Tree")
    [
      let node setup-nodes 1
      setup-regular-tree
    ]
    if (network-type = "Custom Distribution")
    [
      setup-custom-distribution
    ]
  
    if auto-set [
      set-state
    ]
    if node-labels != 0 [
      ask turtles [set label who]
    ]
    change-link-state-of links
    set plot-metric "Degree Distribution"
    update-plot-metric
  ]
  set click? false
  set init? true
  reset-ticks
end

to set-state
  if (count turtles > 0) [
    set-current-plot "Disease Prevalence"
    reset-ticks
    clear-plot
    set min-deg round(abs(min-deg)) ; Needs to be non-negative integer
    if (set-state-by = "Number of nodes") [
      if (num/frac < 1 or (num/frac mod 1) != 0) [
        user-message "For number of nodes, num/frac must be a positive integer."
        stop
      ]
      let candidates turtles with [susceptible? and (min-deg <= count link-neighbors)]
      ask n-of num/frac candidates [ ifelse (set-state-to = "Infectious") [ become-infectious ] [ become-removed ] ]
    ]
    if (set-state-by = "Fraction of nodes") [
      if (num/frac < 0 or num/frac > 1) [
        user-message "For fraction of nodes, num/frac must be a number between 0 and 1."
        stop
      ]
      let candidates turtles with [susceptible? and (min-deg <= count link-neighbors)]
      ask n-of round((count candidates) * num/frac) candidates [ ifelse (set-state-to = "Infectious") [ become-infectious ] [ become-removed ] ]
    ]
    if (set-state-by = "Vector from input") [
      let node-list read-from-string user-input "Enter list of turtles"
      if (is-number? node-list) [
        set node-list (list node-list)
      ]
      let candidates turtle-set map [turtle ?] node-list
      ask candidates [ ifelse (set-state-to = "Infectious") [ become-infectious ] [ become-removed ] ]
    ]
    if (set-state-by = "Vector from file") [
      let candidates turtles-from-file ""
      ask candidates [ ifelse (set-state-to = "Infectious") [ become-infectious ] [ become-removed ] ]
    ]
    change-link-state-of links
    set init? true
  ]
end

to last-init
  if not init?
  [
    set init? true ;Redundant, but necessary to make sure any pre-processing before go is performed (like max-infected)
    set-current-plot "Disease Prevalence"
    clear-plot
    ask turtles
    [
      ifelse init-infectious?
      [
        become-infectious
      ]
      [
        ifelse init-removed?
        [
          become-removed  
        ]
        [
          ifelse init-latent?
          [
            set latent-period true
            become-latent
          ]
          [
            become-susceptible
          ]
        ]
      ]
    ]
    change-link-state-of links
    reset-ticks
  ]
end

to-report setup-nodes [num]
  let nodes []
  crt num
  [
    set nodes lput self nodes
    setxy (0.95 * max-pxcor * cos((random-float 1) * 360)) (0.95 * max-pycor * sin((random-float 1) * 360))
    become-susceptible
  ]
  report turtle-set nodes
end

to link-em-up
  if (count turtles > 0) [
    ifelse mouse-down?
    [
      if not click?
      [
        set click? true
        let candidate min-one-of turtles [distancexy mouse-xcor mouse-ycor]
        ifelse turtle-head = nobody [
          set turtle-head candidate
          ask candidate [set color white]
        ] [
          ifelse spawn-kill = "Spawn" [
            ask turtle-head [create-link-with candidate [change-link-state-of self]]
          ] [
            ask turtle-head [if link-neighbor? candidate [ ask link-with candidate [ die ] ] ]
          ]
          reset-state turtle-head
          set turtle-head nobody
          update-plot-metric
        ]
      ]
    ] [
      if click?
      [
        set click? false
      ]
    ]
    display
  ]
end

to spawn
  ifelse mouse-down?
  [
    if not click?
    [
      set click? true
      set num-nodes count turtles
      ifelse spawn-kill = "Spawn" [
        crt 1 [
          setxy (mouse-xcor) (mouse-ycor)
          become-susceptible
          set init-infectious? false ; Can this go in become-susceptible?
          set init-removed? false
          set init-latent? false
          set num-nodes num-nodes + 1
        ]
      ] [
        if (num-nodes > 0) [
          ask min-one-of turtles [distancexy mouse-xcor mouse-ycor] [ die ]
          set num-nodes num-nodes - 1
        ]
      ]
      set plot-metric "Degree Distribution"
      update-plot-metric
    ]
  ] [
    if click?
    [
      set click? false
    ]
  ]
  display
end

to toggle-states
  if (count turtles > 0) [
    ifelse mouse-down? 
    [
      if not click? 
      [
        set click? true
        set init? true
        let candidate min-one-of turtles [distancexy mouse-xcor mouse-ycor]
        ask candidate 
        [
          ifelse infectious?
          [
            become-removed
          ]
          [
            ifelse removed?
            [
              become-susceptible
            ]
            [
              ifelse susceptible? and latent-period [
                become-latent
              ] [
                become-infectious
              ]
            ]
          ]
        ]
        change-link-state-of [my-links] of candidate
      ]
    ]
    [
      if click?
      [
        set click? false
      ]
    ]
    display
  ]
end

to randomize-edges [num]
  if (count turtles > 0) [
    if (num = []) [
      set num floor (num-nodes * (num-nodes - 1) / 2)
    ]
    let rand-links []
    let nodes1 []
    let nodes2 []
    repeat num [
      set rand-links sort n-of 2 links
      set nodes1 sort-by [true] [both-ends] of item 0 rand-links
      set nodes2 sort-by [true] [both-ends] of item 1 rand-links
      ;; Only procede if all nodes are unique
      if (length remove-duplicates (sentence nodes1 nodes2)) = 4 [ ;;if reduce [?1 and ?2] (map [not member? ?1 ?2] nodes1 (list nodes2 nodes2)) [
        ifelse link [who] of first nodes1 [who] of last nodes2 = nobody and link [who] of last nodes1 [who] of first nodes2 = nobody [
          ask item 0 rand-links [ die ]
          ask item 1 rand-links [ die ]
          ask first nodes1 [ create-link-with last nodes2 [change-link-state-of self]]
          ask last nodes1 [ create-link-with first nodes2 [change-link-state-of self]]
        ] [
          if link [who] of first nodes1 [who] of first nodes2 = nobody and link [who] of last nodes1 [who] of last nodes2 = nobody [
            ask item 0 rand-links [ die ]
            ask item 1 rand-links [ die ]
            ask first nodes1 [ create-link-with first nodes2 [change-link-state-of self]]
            ask last nodes1 [ create-link-with last nodes2 [change-link-state-of self]]
          ] 
        ]
      ]
    ]
  ]
end

to havel-hakimi
  let num-links-left (reduce + [degree] of turtles) / 2
  let steve []
  let num-stubs 0
  let friends []
  while [num-links-left > 0]
  [
    set steve max-one-of turtles [degree]
    set num-stubs ([degree] of steve)
    set num-links-left num-links-left - num-stubs
    ask steve [
      set degree 0
      ifelse (count turtles with [degree > 0] >= num-stubs) [
        set friends max-n-of num-stubs turtles with [degree > 0] [degree]
        create-links-with friends
        ask friends [
          set degree degree - 1
        ]
      ] [
        user-message "Degree sequence is not realizable as an undirected graph!"
      ]
    ]
  ]
end

to-report is-realizable [degrees]
  set degrees sort-by > degrees
  let sum-d butfirst reduce [lput (?2 + last ?1) ?1] fput [0] degrees ;; Cumulative sum
  let realizable (last sum-d mod 2) = 0
  if realizable [
    let k 1
    while [realizable and k <= (length degrees)] [
      let min-d sum map [min list (item ? degrees) k] n-values ((length degrees) - k) [? + k]
      set realizable ((k * (k - 1) + min-d - item (k - 1) sum-d) >= 0)
      set k k + 1
    ]
  ]
  report realizable
end

to setup-random-regular
  layout-circle (sort turtles) max-pxcor - 1
  if (lambda < 1 or (lambda mod 1) != 0) [
    clean
    user-message "For random regular graphs, lambda must be a positive integer."
    stop
  ]
  ask turtles [set degree lambda]
  ifelse is-realizable [degree] of turtles [
    havel-hakimi
    randomize-edges []
  ] [
    print "Degree sequence is not realizable as an undirected graph!"
    clean
  ]
end

to setup-custom-degrees [degrees]
  ifelse is-realizable degrees [
    set num-nodes length degrees
    let nodes setup-nodes num-nodes
    layout-circle (sort turtles) max-pxcor - 1
    ask turtles [ set degree item who degrees ]
    havel-hakimi
    randomize-edges []
  ] [
    print "Degree sequence is not realizable as an undirected graph!"
    clean
  ]
end

to setup-custom-distribution
  ifelse (length(distribution) > 0) [
    set num-nodes max list (1 + length distribution) num-nodes
    let nodes setup-nodes num-nodes
    set-degrees-from-distribution distribution
    ifelse is-realizable [degree] of turtles [
      havel-hakimi
      randomize-edges []
    ] [
      print "Degree sequence is not realizable as an undirected graph!"
      clean
    ] 
  ] [
    print "Distribution is not loaded!"
  ]
end

to setup-regular-tree
  if (lambda < 1 or (lambda mod 1) != 0 or d < 1 or (d mod 1) != 0) [
    clean
    user-message "For regular trees, the depth (lambda) and number of branches (d) must be positive integers."
    stop
  ]

  let cnt 1
  let roots sort turtles
  let leaves []
  let pile []
  while [cnt <= floor(lambda)] [
    foreach roots [
      set leaves setup-nodes floor(d)
      ask ? [create-links-with leaves]
      set pile (sentence pile sort leaves)
    ]
    set roots pile
    set pile []
    set cnt cnt + 1
  ]
  set num-nodes count turtles
end

to setup-spatially-clustered-network
  ;; Function code from Virus on a Network module (by Uri Wilensky)
  if (lambda < 0) [
    user-message "Local edge density (lambda) must be a non-negative number."
    stop
  ]

  let num-links (lambda * num-nodes) / 2
  while [count links < num-links ]
  [
    ask one-of turtles
    [
      let choice (min-one-of (other turtles with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  ; make the network look a little prettier
  repeat 10
  [
    layout-spring turtles links 0.3 (world-width / (sqrt num-nodes)) 1
  ]
end

to setup-complete-graph
  ask turtles [
    create-links-with turtles with [self > myself]
  ]
  layout-circle turtles (max-pxcor - 1)
end

to setup-nne1
  if (d < 0 or (d mod 1) != 0) [
    clean
    user-message "In this context, d must be a non-negative integer."
    stop
  ]

  let num min list d floor(num-nodes / 2)
  layout-circle (sort turtles) max-pxcor - 1
  let ctr 0
  while [ctr < num-nodes]
  [
    let n 1
    while [n <= num]
    [
      ask turtle ctr [ 
        create-link-with turtle ((ctr + n) mod num-nodes) 
        create-link-with turtle ((ctr - n) mod num-nodes)
      ]
      set n n + 1
    ]
    set ctr ctr + 1
  ]
end

to setup-small-world-er [dim]
  ifelse (dim = 1)
  [ 
    let nodes setup-nodes num-nodes
    setup-nne1 
  ] [ 
    setup-nne2 
  ]
  setup-erdos-renyi
end

to setup-nne2
  if (d < 0 or (d mod 1) != 0) [
    clean
    user-message "In this context, d must be a non-negative integer."
    stop
  ]
  
  ; create the grid of nodes
  let m last filter [remainder num-nodes ? = 0] n-values floor(sqrt(num-nodes)) [? + 1]
  let n num-nodes / m
  let x-width (world-width) / n
  let y-width (world-width) / m
  
  let i 0
  let j 0
  while [i < n] [
    set j 0
    while [j < m] [
      ask setup-nodes 1 [
        setxy (min-pxcor - 0.5 + x-width * (i + 0.5)) (min-pycor - 0.5 + y-width * (j + 0.5))
      ]
      set j j + 1
    ]
    set i i + 1
  ]
  
  let x-rad (d - 1 + 0.01) * (x-width)
  let y-rad (d - 1 + 0.01) * (y-width)
  ask turtles
  [
    let fturtle self
    ifelse (d = 1) [
      ask turtles with [(xcor = [xcor] of fturtle and (distancexy xcor [ycor] of fturtle) <= 1.01 * y-width) or ((distancexy [xcor] of fturtle ycor) <= 1.01 * x-width and ycor = [ycor] of fturtle)] [
        if (self != fturtle) and (not link-neighbor? fturtle)
        [
          create-link-with fturtle
        ]
      ]
    ] [
      ask turtles with [(distancexy [xcor] of fturtle ycor) <= x-rad and (distancexy xcor [ycor] of fturtle) <= y-rad]
      [
        if (self != fturtle) and (not link-neighbor? fturtle)
        [
          create-link-with fturtle
        ]
      ]
    ]
  ]
  set num-nodes count turtles
end

to setup-erdos-renyi
  if (lambda < 0) [
    clean
    user-message "The average degree (lambda) must be a non-negative number."
    stop
  ]

  ;; Give each pair of turtles an equal chance of creating a link
  ask turtles [
    ;; we use "self > myself" here so that each pair of turtles is only considered once
    create-links-with turtles with [self > myself and
                                    random-float 1.0 < (lambda / (num-nodes - 1))]
  ]
end 

to set-degrees-from-distribution [f]
  ; Assumes length f = num-nodes and num-nodes turtles already exist
  let cum-f butfirst reduce [lput (?2 + last ?1) ?1] fput [0] f ;; Cumulative sum
  let rand 0
  let i 1
  while [i <= num-nodes] [
    set rand random-float (last cum-f)
    ask turtle (i - 1) [ set degree (length (filter [? < rand] cum-f)) ]
    set i i + 1
  ]  
end

to setup-generic-scale-free
  if (lambda < 1) [
    clean
    user-message "Power-law exponent (lambda) must be a number greater than or equal to 1."
    stop
  ]

  let nodes setup-nodes num-nodes
  layout-circle (sort turtles) max-pxcor - 1
  set distribution fput 0 map [(1 / ?) ^ lambda] n-values (num-nodes - 1) [1 + ?]
  set-degrees-from-distribution distribution
  ifelse is-realizable [degree] of turtles [
    havel-hakimi
    randomize-edges []
  ] [
    print "Degree sequence is not realizable as an undirected graph!"
    clean
  ]
end

to setup-pref-attach
  if (d < 1 or lambda < 1 or (d mod 1 != 0) or (lambda mod 1 != 0)) [
    clean
    user-message "The size of the initial complete graph (lambda) and the number of connections at each step (d) be positive integers."
    stop
  ]
  if (lambda > num-nodes) [
    clean
    user-message "The size of the initial complete graph (lambda) cannot exceed the number of nodes."
    stop
  ]
  if (d > lambda) [
    clean
    user-message "The size of the initial complete graph (lambda) must be larger than the number of connections at each step (d)."
    stop
  ]
  let m0 lambda
  let m d
  let nodes setup-nodes m0
  setup-complete-graph
  display
  ask turtles [set degree m0 - 1]
  
  let ctr count turtles
  while [ctr < num-nodes]
  [
    let degrees map [[degree] of ?] sort turtles
    let cumdeg butfirst reduce [lput (?2 + last ?1) ?1] fput [0] degrees
    ask setup-nodes 1 [
      let i 1
      set degree m
      while [i <= m] [
        let rand random-float (last cumdeg)
        let friend turtle length (filter [? < rand] cumdeg)
        if (not link-neighbor? friend) [
          create-link-with friend
          ask friend [set degree degree + 1]
          set i i + 1
        ]
      ]
    ]        
    set ctr ctr + 1
    sf-layout 25    
    display
  ]
    
  repeat 50 [sf-layout 4]
end

to fix-scale
  if (count turtles > 0) [
    let xcenter (max [xcor] of turtles + min [xcor] of turtles) / 2
    let ycenter (max [ycor] of turtles + min [ycor] of turtles) / 2
    ask turtles [
      set xcor xcor - xcenter
      set ycor ycor - ycenter
    ]
    
    let c (max (list max-pxcor max-pycor)) / (max sentence (max [abs xcor] of turtles) (max [abs ycor] of turtles))
    ask turtles [
      setxy (0.95 * c * xcor) (0.95 * c * ycor)
    ]
  ]
  display
end

to sf-layout [num]
  ;; Function code from Preferential Attachment module (by Uri Wilensky)
  repeat num [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    ;fix-scale
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset sf-limit-magnitude x-offset 0.1
  set y-offset sf-limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report sf-limit-magnitude [number limit]
  ;; Function code from Preferential Attachment module (by Uri Wilensky)
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end

to go
  if init?
  [
    if (time-step <= 0) [
      user-message "Time step must be a positive number."
      stop
    ]
    if ((model-time = "Discrete") and ((infection-prob < 0) or (infection-prob > 1) or (lose-immunity-prob < 0) or (lose-immunity-prob > 1) or (end-latency-prob < 0) or (end-latency-prob > 1))) [
      user-message "All probabilities must be between 0 and 1."
      stop
    ]
    if ((model-time = "Continuous") and ((infection-rate < 0) or (lose-immunity-rate < 0) or (end-latency-prob < 0))) [
      user-message "All rates must be non-negative numbers."
      stop
    ]
    set init? false
    ask turtles
    [
      set init-infectious? infectious?
      set init-removed? removed?
      set init-latent? latent?
      set init-susceptible? susceptible?
    ]
    set max-infected (count turtles with [infectious?])
  ]
  if all? turtles [susceptible? or removed?]
  [ 
    set-current-plot "Disease Prevalence"
    if (0 < ticks) [
      set-plot-x-range 0 precision ticks 5
    ]
    stop 
  ]
    
  let change-state-list []
  let dt time-step
  ifelse (model-time = "Discrete")
  [ 
    ;; List method (In parallel)
    let change-susceptible-list sort turtles with [(susceptible? and any? link-neighbors with [infectious?]) and random-float 1 < ( 1 - ((1 - infection-prob) ^ (count link-neighbors with [infectious?])))]
    let change-latency-list sort turtles with [latent? and random-float 1 < end-latency-prob]
    let change-infection-list sort turtles with [infectious? and random-float 1 < end-infection-prob]
    let change-removed-list sort turtles with [removed? and random-float 1 < lose-immunity-prob]

    set change-state-list (sentence change-infection-list change-latency-list change-removed-list change-susceptible-list)
  ]
  [
    ;; For efficiency, modify later so only updating list, not creating every time
    ;; OR, don't create any lists.  Has potential to be MUCH faster. 
    let susceptible-list sort turtles with [susceptible? and any? link-neighbors with [infectious?]]
    let latent-list sort turtles with [latent?]
    let infectious-list sort turtles with [infectious?]
    let removed-list sort turtles with [removed?]
    let all-list (sentence infectious-list latent-list removed-list susceptible-list)
    
    let rate-list ( sentence (n-values (length infectious-list) [end-infection-rate]) (n-values (length latent-list) [end-latency-rate]) (n-values (length removed-list) [lose-immunity-rate]) (map [(count [link-neighbors with [infectious?]] of ?) * infection-rate] susceptible-list) )
    let cum-rate-list butfirst reduce [lput (?2 + last ?1) ?1] fput [0] rate-list ;; Cumulative sum
    
    let rnum random-float (last cum-rate-list)
    
    set change-state-list (list item (length (filter [? < rnum] cum-rate-list)) all-list)
    
    if ((last cum-rate-list) = 0) [
      print "Reached steady state!  Stopping simulation."
      stop
    ]
    set dt random-exponential (1 / (last cum-rate-list))
  ]
  
  foreach change-state-list [
    ask ? [
      ifelse infectious?
      [
        ifelse gain-immunity
        [
          become-removed
        ]
        [
          become-susceptible
        ]
      ]
      [
        ifelse removed?
        [
          become-susceptible
        ]
        [
          ifelse latent? or (susceptible? and not latent-period)
          [
            become-infectious
          ]
          [
            become-latent
          ]
        ]
      ]
    ]
  ]
  change-link-state-of link-set [my-links] of turtle-set change-state-list
  set max-infected max list max-infected (count turtles with [ infectious? ])
  tick-advance dt
  update-plots
end

to change-link-state-of [changed]
  ask changed [
    set color white
    ifelse any? both-ends with [removed?] [
      set color removed-link-color
    ] [
      if any? both-ends with [infectious?] and any? both-ends with [susceptible?] [
        set color infectious-link-color
      ]
    ]
  ]
end

to become-susceptible  ;; turtle procedure
  set susceptible? true
  set latent? false
  set infectious? false
  set removed? false
  set color susceptible-color
end

to become-latent
  set susceptible? false
  set latent? true
  set infectious? false
  set removed? false
  set color latent-color
end

to become-infectious
  set susceptible? false
  set latent? false
  set infectious? true
  set removed? false
  set color infectious-color
end

to become-removed
  set susceptible? false
  set latent? false
  set infectious? false
  set removed? true
  set color removed-color
end

to reset-state [steve]
  ask steve [
    if susceptible? [
      become-susceptible
    ]
    if latent? [
      become-latent
    ]
    if infectious? [
      become-infectious
    ]
    if removed? [
      become-removed
    ]
  ] 
end

to compute-clustering-coefficients
  let N count turtles
  let L count links
  let ED []
  if (N > 1) [
    set ED (L / (N * (N - 1) / 2))
  ]
  ask turtles [
    let friends link-neighbors
    let kv count friends
    ifelse (kv > 1) [
      let ncnt 0
      ask friends [
        set ncnt ncnt + count (link-neighbors with [member? self friends])
      ]
      set clustering ncnt / (kv * (kv - 1))
    ] [
      set clustering ED
    ]
  ]
end

to compute-shortest-paths
  ; Compute shortest path using Dijkstra's algorithm
  set conncomp []
  let N count turtles
  let cnt 0
  let current nobody
  ask turtles [
    foreach sort turtles [  ;; Workaround - turtles can't ask other turtles, so have to use foreach
      ask ? [
        set unvisited true
        set dist N
      ]
    ]
    set current self
    set dist 0
    while [(count turtles with [unvisited] > 0) and (min([dist] of turtles with [unvisited]) < N)] [
      ask [link-neighbors] of current [ set dist min (list dist ([dist] of current + 1)) ]
      ask current [ set unvisited false ]
      set current min-one-of turtles with [unvisited] [dist]
    ]
    set conncomp lput sort turtles with [not unvisited] conncomp
    set shortest-path map [[dist] of ?] last conncomp
  ]
  set conncomp sort-by [length ?1 > length ?2] remove-duplicates conncomp
end

to output-parameters
  let N count turtles
  let L count links
  print ""
  print "----------------------"
  let sigdig 5
  print "Simulation parameters:"
  let meandeg 0
  if (count turtles != 0) [
    set meandeg mean ([count link-neighbors] of turtles)
  ]
  ifelse model-time = "Discrete" [
    type "<tau> = " 
    print precision (time-step / end-infection-prob) sigdig
    type "R0 = "
    print precision (meandeg * infection-prob / (end-infection-prob + infection-prob - infection-prob * end-infection-prob)) sigdig
  ] [
    type "<tau> = "
    print precision (1 / end-infection-rate) sigdig
    type "R0 = "
    print precision (meandeg * infection-rate / (end-infection-rate + infection-rate)) sigdig
  ]
  type "Maximum number of simultaneous infections = "
  ifelse max-infected != [] [
    print precision max-infected sigdig
  ] [
    print "N/A"
  ]
  print ""
  print "Network parameters:"
  type "Mean degree = " 
  ifelse N != 0 [
    print precision meandeg sigdig
  ] [
    print "N/A"
  ]
  type "Edge density = "
  let ED []
  ifelse N > 1 [
    set ED (L / (N * (N - 1) / 2))
    print precision ED sigdig
  ] [
    print "N/A"
  ]
  let clist []
  type "Clustering coefficient = " 
  if N > 1 [
    ifelse (L != (N * (N - 1) / 2)) [ ; Current compute-clustering-coefficient code is inefficient for complete graphs
      compute-clustering-coefficients
    ] [
      ask turtles [ set clustering 1 ]
    ]
    set clist [clustering] of turtles
  ] 
  ifelse not empty? clist [
    print precision mean clist sigdig
  ] [
    print "N/A"
  ]
  type "Normalized clustering coefficient = "
  ; ask turtles with [not is-number? clustering] [set clustering ED]
  ; set clist [clustering] of turtles
  ifelse not empty? clist [
    ifelse (ED = 0) [ ; Empty graph
      print "1"
    ] [
      print precision ((mean clist) / ED) sigdig
    ]
  ] [
    print "N/A"
  ]
  type "Number of connected components = "
  ifelse (N != 0) [
    compute-shortest-paths
    print length(conncomp)
  ] [
    print ""
  ]  
  type "Largest component (as proportion of network) = "
  ifelse (N != 0) [
    print length(item 0 conncomp) / (count turtles)
  ] [
    print ""
  ]
  type "Average path length in largest component = "
  ifelse (N != 0) [
    let myturtles item 0 conncomp  ; Largest component only
    let N0 length(item 0 conncomp)
    let PL 0
    if (N0 > 1) [
      set PL ((reduce + map [sum([shortest-path] of ?)] myturtles) / (N0 * (N0 - 1)))
    ]
    print precision PL sigdig
  ] [
    print ""
  ]
  type "Diameter of largest component = "
  ifelse (N != 0) [
    let myturtles turtle-set item 0 conncomp  ; Largest component only
    let spaths []
    ask myturtles [
      set spaths (sentence spaths filter [? > 0] shortest-path)
    ]
    let diam 0
    if (not empty? spaths) [
      set diam max(spaths)
    ]
    print precision diam sigdig
  ] [
    print ""
  ]
end

to update-plot-metric
  set-current-plot "Network Metrics"
  clear-plot
  if (plot-metric = "Degree Distribution") [
    plot-degree-distribution
  ]
  if (plot-metric = "Clustering Coeffs") [
    plot-clustering-coefficients false
  ]
  if (plot-metric = "Normalized Coeffs") [
    plot-clustering-coefficients true
  ]
  if (plot-metric = "Shortest Paths") [
    plot-shortest-paths
  ]
  if (plot-metric = "Custom Distribution") [
    plot-probability-distribution
  ]
end

to plot-histogram [bins hist]
  if length(remove-duplicates bins) = 1 [
    let M 1
    let L length(bins)
    ifelse ((item 0 bins) != 0) [
      set M last bins
    ] [
      set hist replace-item 0 hist last hist
      set hist replace-item (length(hist) - 1) hist 0
    ]
    set bins n-values L [? * (M / L)]
  ]
  let step (item 1 bins) - (item 0 bins)
  set-plot-pen-interval step
  let cnt 0
  while [cnt < length(bins)] [
    if item cnt hist > 0 [
      plot-pen-down
      plotxy item cnt bins item cnt hist
      plot-pen-up
    ]
    set cnt cnt + 1
  ]
  let xlim0 0
  let xlim1 last bins
  if (step > 0) [ 
    set xlim0 item 0 bins
    set xlim1 step + last bins 
  ]
  if (xlim1 = 0) [
    set xlim1 1
  ]
  if (abs(100 * xlim1 - int(100 * xlim1)) > 0) [ ; For continuous variables with homogeneity
    set xlim1 (int(100 * (xlim1 + 0.01)) / 100)
  ]
  set-plot-x-range precision xlim0 2 precision xlim1 2
  set-plot-y-range 0 precision (max hist) 2
end

to plot-degree-distribution
  if (count turtles > 0) [
    let bins n-values (1 + max [count link-neighbors] of turtles) [?]
    let hist map [count turtles with [count link-neighbors = ?]] bins
    if (length(bins) = 1) [ ; No links in the system
      set bins list 0 1
      set hist list (item 0 hist) 0
    ]
    plot-histogram bins hist
  ]
end

to plot-clustering-coefficients [normalized]
  let N count turtles
  let L count links
  if (N > 1) [ ; Need at least two nodes for this to make sense
    ifelse (L != (N * (N - 1) / 2)) [ ; Current compute-clustering-coefficient code is inefficient for complete graphs
      compute-clustering-coefficients
    ] [
      ask turtles [ set clustering 1 ]
    ]
    let coeffs [clustering] of turtles
    if (normalized) [
      let ED (L / (N * (N - 1) / 2))
      ifelse (ED = 0) [ ; Empty graph
        ask turtles [ set clustering 1 ]
      ] [
        ask turtles [ set clustering clustering / ED ]
      ]
      set coeffs [clustering] of turtles
    ]
    let step (max(coeffs) - min(coeffs)) / nbins
    let bins n-values nbins [min(coeffs) + ? * step]
    let hist map [count turtles with [(is-number? clustering) and (? <= clustering) and (clustering < (? + step))]] bins
    set hist replace-item (length(bins) - 1) hist (last hist + count turtles with [clustering = max(coeffs)])
    plot-histogram bins hist
  ]
end

to plot-shortest-paths
  if (count turtles != 0) [
    compute-shortest-paths
    let myturtles turtle-set item 0 conncomp  ; Largest component only
    let spaths []
    ask myturtles [
      set spaths (sentence spaths filter [? > 0] shortest-path)
    ]
    let diam 0
    if (not empty? spaths) [ ; Handles case of empty graph
      set diam max(spaths)
    ]
    let bins n-values diam [1 + ?]
    let hist []
    foreach bins [
      let b ?
      set hist lput length(filter [? = b] spaths) hist
    ]
    if (not empty? bins) [
      if (length(bins) = 1) [ ; diam = 1
        set bins list 1 2
        set hist list (item 0 hist) 0
      ]
      plot-histogram bins hist
    ]
  ]
end

to plot-probability-distribution
  if not empty? distribution [
    let bins n-values length(distribution) [?]
    let hist map [? / sum(distribution)] distribution
    plot-histogram bins hist
  ]
end

to-report turtles-from-file [filename]
  ifelse (filename = "") [
    file-open user-file
  ] [
    file-open filename
  ]
  let output []
  if not file-at-end? [
    set output file-read
  ]
  file-close
  report turtle-set map [turtle ?] output
end

to-report split-after-first-word [string]
  let n position " " string
  ifelse (n = false) [
    report list string ""
  ] [
    report list (substring string 0 n) (substring string (n + 1) length(string))
  ]
end

to load-from-file [filename]
  carefully [
    ifelse (filename = "") [
      file-open user-file
    ] [
      file-open filename
    ]
  ] [
    print "Problem with loading file!"
    stop
  ]
  let itype file-read-line
  let nitype ""
  let nptype ""
  let items []
  let splitline []
  let line ""
  while [not file-at-end?] [
    if (itype = "distribution") [
      clean
      set distribution file-read
      let M sum(distribution)
      set distribution map [? / M] distribution
      set network-type "Custom Distribution"
      set plot-metric "Custom Distribution"
      update-plot-metric
      print "Distribution loaded.  Press `New' to create a network from this distribution."
    ]
    if (itype = "degrees") [
      clean
      setup-custom-degrees file-read
    ]
    if (itype = "network") [
      clean 
      set nitype "set"
      set nptype ""
      let simple false
      let firstnum true
      while [not file-at-end? and (member? nitype ["edge" "state" "node" "set"] or simple)] [
        set line file-read-line
        set splitline split-after-first-word line
        set nitype item 0 splitline
        carefully [ set simple is-number? read-from-string nitype ] [ set simple false ]
        ifelse (not simple) [
          if (nitype = "set") [
            set splitline split-after-first-word item 1 splitline
            set nptype item 0 splitline
            if (nptype = "num-nodes") [
              set num-nodes read-from-string item 1 splitline
              let nodes setup-nodes num-nodes
            ]
            if (nptype = "network-type") [
              set network-type item 1 splitline
            ]
            if (nptype = "lambda") [
              set lambda read-from-string item 1 splitline
            ]
            if (nptype = "d") [
              set d read-from-string item 1 splitline
            ]
          ]
          if (nitype = "node") [
            set items read-from-string (word "[" item 1 splitline "]")
            ask turtle item 0 items [ 
              setxy item 1 items item 2 items 
            ]
          ]
          if (nitype = "edge") [
            set items read-from-string (word "[" item 1 splitline "]")
            ask turtle item 0 items [ create-link-with turtle item 1 items ]
          ]
          if (nitype = "state") [
            set items split-after-first-word item 1 splitline
            ask turtle read-from-string item 0 items [
              let state item 1 items
              if (state = "S") [
                become-susceptible
              ]
              if (state = "E") [
                become-latent
              ]
              if (state = "I") [
                become-infectious
              ]
              if (state = "R") [
                become-removed
              ]
            ]
          ]
        ]
        [
          ; Simple file format
          ifelse firstnum [
            ;Number of nodes
            set firstnum false
            set num-nodes read-from-string nitype
            let nodes setup-nodes num-nodes
          ] [
            ;List of edges
            set items read-from-string (word "[" line "]")
            ask turtle item 0 items [ create-link-with turtle item 1 items ]            
          ]
        ]
      ]
      change-link-state-of links
      set click? false
      set init? true
      set itype line
      set plot-metric "Degree Distribution"
      update-plot-metric
    ]
    if (itype = "parameters") [
      set nitype "set"
      set nptype ""
      while [not file-at-end? and nitype = "set" ] [
        set line file-read-line
        set splitline split-after-first-word line
        set nitype item 0 splitline
        if (nitype = "set") [
          set splitline split-after-first-word item 1 splitline
          set nptype item 0 splitline
          if (nptype = "model-time") [
            set model-time item 1 splitline
          ]
          if (nptype = "time-step") [
            set time-step read-from-string item 1 splitline
          ]
          if (nptype = "infection-rate") [
            set infection-rate read-from-string item 1 splitline
          ]
          if (nptype = "infection-prob") [
            set infection-prob read-from-string item 1 splitline
          ]
          if (nptype = "end-infection-rate") [
            set end-infection-rate read-from-string item 1 splitline
          ]
          if (nptype = "end-infection-prob") [
            set end-infection-prob read-from-string item 1 splitline
          ]
          if (nptype = "lose-immunity-rate") [
            set lose-immunity-rate read-from-string item 1 splitline
          ]
          if (nptype = "lose-immunity-prob") [
            set lose-immunity-prob read-from-string item 1 splitline
          ]
          if (nptype = "end-latency-rate") [
            set end-latency-rate read-from-string item 1 splitline
          ]
          if (nptype = "end-latency-prob") [
            set end-latency-prob read-from-string item 1 splitline
          ]
          if (nptype = "gain-immunity") [
            set gain-immunity read-from-string item 1 splitline
          ]
          if (nptype = "latent-period") [
            set latent-period read-from-string item 1 splitline
          ]
        ]
      ]
      set itype line
    ]
  ]
  file-close
end

to save-to-file
  let save-type user-one-of "What would you like to save?" ["Network" "Parameters" "All"]
  let filename user-new-file
  if (filename != false) [
    if (file-exists? filename) [
      file-delete filename
    ]
    file-open filename
    if (save-type = "Network" or save-type = "All") [
      file-print "network"
      file-print word "set num-nodes " num-nodes
      file-print word "set network-type " network-type
      file-print word "set lambda " lambda
      file-print word "set d " d
      foreach sort turtles [
        ask ? [
          file-print (word "node " who " " xcor " " ycor)
        ]
      ]
      ask links [
        file-type "edge"
        ask both-ends [
          file-type word " " who
        ]
        file-print ""
      ]
      foreach sort turtles [
        ask ? [
          if not susceptible? [
            file-type (word "state " who " ")
            if latent? [
              file-print "E"
            ]
            if infectious? [
              file-print "I"
            ]
            if removed? [
              file-print "R"
            ]
          ]
        ]
      ]
    ]
    if (save-type = "Parameters" or save-type = "All") [
      file-print "parameters"
      file-print word "set model-time " model-time
      file-print word "set time-step " time-step
      file-print word "set infection-rate " infection-rate
      file-print word "set infection-prob " infection-prob
      file-print word "set end-infection-rate " end-infection-rate
      file-print word "set end-infection-prob " end-infection-prob
      file-print word "set lose-immunity-rate " lose-immunity-rate
      file-print word "set lose-immunity-prob " lose-immunity-prob
      file-print word "set end-latency-rate " end-latency-rate
      file-print word "set end-latency-prob " end-latency-prob
      file-print word "set gain-immunity " gain-immunity
      file-print word "set latent-period " latent-period
    ]
    file-close
  ]
end

; Copyright 2014 M. Drew LaMar
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
426
21
879
495
21
21
10.30233
1
10
1
1
1
0
0
0
1
-21
21
-21
21
1
1
1
ticks
30.0

BUTTON
1142
53
1227
87
New
new-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1293
53
1358
87
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1144
375
1363
495
Disease Prevalence
time
% nodes
0.0
0.0
0.0
100.0
true
true
"" ""
PENS
"S " 1.0 0 -10899396 true "" "if count turtles > 0 [\n  plotxy ticks (count turtles with [susceptible?]) / (count turtles) * 100\n]"
"E " 1.0 0 -4079321 true "" "if count turtles > 0 [\nplotxy ticks (count turtles with [latent?]) / (count turtles) * 100\n]"
"I " 1.0 0 -2674135 true "" "if count turtles > 0 [\nplotxy ticks (count turtles with [infectious?]) / (count turtles) * 100\n]"
"R " 1.0 0 -11053225 true "" "if count turtles > 0 [\nplotxy ticks (count turtles with [removed?]) / (count turtles) * 100\n]"

BUTTON
1287
268
1360
301
Select
toggle-states
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
900
52
1109
97
network-type
network-type
"Complete Graph" "Empty Graph" "Erdos-Renyi" "Nearest-neighbor 1" "Nearest-neighbor 2" "Small World 1" "Small World 2" "Preferential Attachment" "Generic Scale-free" "Spatially Clustered" "Random Regular" "Regular Tree" "Custom Distribution"
0

CHOOSER
18
60
169
105
model-time
model-time
"Continuous" "Discrete"
1

BUTTON
1227
53
1293
87
Last
last-init
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1142
87
1227
120
Defaults
set-defaults
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
25
195
175
219
Continuous
14
15.0
1

INPUTBOX
21
219
193
279
infection-rate
1.4
1
0
Number

INPUTBOX
21
288
193
348
end-infection-rate
1
1
0
Number

TEXTBOX
233
195
383
219
Discrete
14
15.0
1

INPUTBOX
233
219
405
279
infection-prob
0.02761163319875315
1
0
Number

INPUTBOX
234
289
406
349
end-infection-prob
0.019801326693244747
1
0
Number

INPUTBOX
284
59
401
119
time-step
0.02
1
0
Number

BUTTON
300
461
406
495
Discrete Approx
set infection-prob 1 - exp(-1 * infection-rate * time-step)\nset end-infection-prob 1 - exp(-1 * end-infection-rate * time-step)\nset lose-immunity-prob 1 - exp(-1 * lose-immunity-rate * time-step)\nset end-latency-prob 1 - exp(-1 * end-latency-rate * time-step)
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
21
462
149
495
gain-immunity
gain-immunity
0
1
-1000

BUTTON
1049
266
1109
299
Labels
ifelse node-labels = 0 [\n  ask turtles [set label who]\n  set node-labels 1\n] [\n  ask turtles [set label \"\"]\n  set node-labels 0\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
964
266
1049
299
Spring
if (count turtles > 0) [ sf-layout 4 ]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
960
22
1110
44
Network
18
105.0
1

TEXTBOX
1195
21
1388
43
Setup & Go
18
105.0
1

BUTTON
900
266
964
299
Scale
fix-scale
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
164
461
286
494
latent-period
latent-period
1
1
-1000

INPUTBOX
21
358
193
418
end-latency-rate
0
1
0
Number

INPUTBOX
234
359
406
419
end-latency-prob
0
1
0
Number

PLOT
900
375
1109
495
Network Metrics
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 false "" ""

BUTTON
1049
233
1109
266
Metrics
output-parameters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
900
188
956
233
Node
spawn
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
956
188
1012
233
Link
link-em-up
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
1012
188
1109
233
spawn-kill
spawn-kill
"Spawn" "Kill"
0

INPUTBOX
900
97
977
157
num-nodes
120
1
0
Number

INPUTBOX
977
97
1043
157
lambda
5
1
0
Number

INPUTBOX
1043
97
1109
157
d
0.6
1
0
Number

BUTTON
900
233
964
266
Clear
clean\nset num-nodes 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
964
233
1049
266
Randomize
randomize-edges 1\ndisplay
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1293
87
1358
120
Save
save-to-file
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1227
87
1293
120
Load
load-from-file \"\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
1237
163
1360
208
set-state-by
set-state-by
"Number of nodes" "Fraction of nodes" "Vector from input" "Vector from file"
0

INPUTBOX
1143
208
1237
268
num/frac
1
1
0
Number

INPUTBOX
1237
208
1360
268
min-deg
0
1
0
Number

BUTTON
1143
268
1215
301
Set
set-state
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
1143
163
1237
208
set-state-to
set-state-to
"Infectious" "Removed"
0

BUTTON
1215
268
1287
301
Reset
ask turtles [ become-susceptible ]\nchange-link-state-of links
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
900
331
1054
376
plot-metric
plot-metric
"Degree Distribution" "Clustering Coeffs" "Normalized Coeffs" "Shortest Paths" "Custom Distribution"
0

BUTTON
1054
331
1109
376
Update
update-plot-metric
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1143
301
1240
334
auto-set
auto-set
1
1
-1000

TEXTBOX
119
160
300
180
Disease Parameters
18
105.0
1

TEXTBOX
112
26
309
51
Numerical Parameters
18
105.0
1

@#$#@#$#@
## TO DO & BUGS

 * Fix bug in loading files (any spaces after name will freeze program)
 * Query user to add .iontw at end of save files (use `user-yes-or-no?` and modify `split-after-first-word` function to take a delimiter - currently delimiter defaults to a space, but the code is useable in the traditional case and in this case with a period)

## INFO

This program can handle most of the tasks of the companion Matlab code and has additional capabilities.

Models can be:

 * S->I (gain-resistance-chance = 0, recovery-chance = 0)
 * S->I->S (gain-resistance-chance = 0, recovery-chance > 0)
 * S->I->R (gain-resistance-chance > 0, lose-resistance-chance = 0)
 * S->I->R->S (gain-resistance-chance > 0, lose-resistance-chance > 0)

The model type can be discrete or continuous.  In the discrete model, at each discrete time step, each infected host will infect each of their uninfected and nonresistant neighbors with probability given by virus-spread-chance.  The continuous model, which is the one described in the lecture, is simulated based on the Gillespie’s algorithm.

The code can handle all network types specified in the network-type drop-down menu. The sliders that control the network properties are:  number-of-nodes, average-node-degree, and percent-rewire.  Note that not all of them are used for each network type.  The 1 and 2 after Nearest-neighbor and Small world refer to the spatial dimension of the networks.  Random regular networks are not currently implemented.

One of the perks of NetLogo is the ability to visualize both network structure and dynamics occuring on this network.  If the user clicks the “Select” button, they will be able to click on a node and cycle through the allowable states (S,I,R).  S is green, I is red, and R is gray.  All R nodes also have their links “hidden” by changing their color to shades of gray, which can be modified with the link-color slider.  If link-color is 0, then the R links are invisible (black).  Higher values make them lighter gray.  Note that you can "Select" nodes even during simulations, and change any parameter of the system while the system is running.

This code is not just for visualization purposes, though.  Batch runs for computing estimates, as in the companion Matlab code, can be accomplished by clicking on Tools->BehaviorSpace and then creating a new experiment.  Multiple runs can be computed, with the output of desired measures sent to a table or spreadsheet.  Analysis can then be done in your program of choice, such as Matlab or Excel.

## REFERENCES

* Stonedahl, F. and Wilensky, U. (2008).  NetLogo Virus on a Network model.  http://ccl.northwestern.edu/netlogo/models/VirusonaNetwork.  Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.
* Wilensky, U. (2005).  NetLogo Preferential Attachment model.  http://ccl.northwestern.edu/netlogo/models/PreferentialAttachment.  Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.
* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2014 M. Drew LaMar and Dmitry Kondrashov.

![CC BY-NC-SA 3.0](http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact M. Drew LaMar at mdlama@wm.edu.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
