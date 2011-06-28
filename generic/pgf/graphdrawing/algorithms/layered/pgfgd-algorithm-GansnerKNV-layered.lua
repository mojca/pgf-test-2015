-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/layered/pgfgd-algorithm-GansnerKNV-layered.lua,v 1.3 2011/06/24 13:45:18 jannis-pohlmann Exp $

pgf.module("pgf.graphdrawing")



GansnerKNVLayered = {}
GansnerKNVLayered.__index = GansnerKNVLayered



--- Implementation of a layered drawing algorithm for directed graphs.
-- 
-- This implementation is based on the paper 
--
--   "A Technique for Drawing Directed Graphs"
--   Gansner, Koutsofios, North, Vo, 1993
--
-- and the reference code in Graphviz/dot (http://www.graphviz.org).
--
-- Modifications compared to the original algorithm are explained in the manual.
--
function drawGraphAlgorithm_GansnerKNV_layered(graph)
  local algorithm = GansnerKNVLayered:new(graph)

  algorithm:initialize()
  algorithm:run()

  orientation.adjust(graph)
end



function GansnerKNVLayered:new(graph)
  local algorithm = {
    -- read graph input parameters
    level_distance = tonumber(graph:getOption('/graph drawing/layered drawing/level distance')),
    sibling_distance = tonumber(graph:getOption('/graph drawing/layered drawing/sibling distance')),

    -- remember the graph for use in the algorithm
    graph = graph,
  }
  setmetatable(algorithm, GansnerKNVLayered)

  -- validate input parameters
  assert(algorithm.level_distance >= 0, 'the level distance needs to be greater than or equal to 0')
  assert(algorithm.sibling_distance >= 0, 'the sibling distance needs to be greater than or equal to 0')

  return algorithm
end



function GansnerKNVLayered:initialize()
  -- reset the tree edge search index
  self.search_index = 1

  -- initialize edge parameters
  for edge in table.value_iter(self.graph.edges) do
    -- read edge parameters
    edge.weight = tonumber(edge:getOption('/graph drawing/layered drawing/weight'))
    edge.minimum_levels = tonumber(edge:getOption('/graph drawing/layered drawing/minimum levels'))

    -- validate edge parameters
    assert(edge.minimum_levels >= 1, 'the edge ' .. tostring(edge) .. ' needs to have a minimum levels value that is greater than 0')

    -- initialize internal edge parameters
    edge.cut_value = 0
    edge.tree_index = -1
  end

  -- initialize nodes
  -- TODO remove the node.marked flag, we only need it in a single
  -- place anyway and there it can be replaced with a node to bool
  -- mapping that states whether the node has been added to the tree
  -- or not
  for node in table.value_iter(self.graph.nodes) do
    node.marked = false
  end
end



function GansnerKNVLayered:run()
  self:preprocess()

  -- reset information needed for ranking
  self.tree = nil
  self.lim = {}
  self.low = {}
  self.parent_edge = {}
  self.ranking = Ranking:new()

  -- rank nodes, that is, assign a layer to each node
  self:rankNodes()

  -- reset information we might want to overwrite later
  self.tree = nil
  self.lim = {}
  self.low = {}
  self.parent_edge = {}

  -- insert dummy (or "virtual") nodes for intermediate ranks on
  -- edges that have a length greater than 1
  self:insertDummyNodes()

  self:reduceEdgeCrossings()
  self:computeCoordinates()

  -- remove the dummy (or "virtual") nodes to restore the original graph
  self:removeDummyNodes()

  self:makeSplines()

  self:postprocess()
end



function GansnerKNVLayered:preprocess()
  -- merge nonempty sets into supernodes
  --
  -- ignore self-loops
  --
  -- merge multiple edges into one edge each, whose weight is the sum of the 
  --   individual edge weights
  --
  -- ignore leaf nodes that are not part of the user-defined sets (their ranks 
  --   are trivially determined)
  --
  -- ensure that supernodes S_min and S_max are assigned first and last ranks
  --   reverse in-edges of S_min
  --   reverse out-edges of S_max
  --
  -- ensure the supernodes S_min and S_max are are the only nodes in these ranks
  --   for all nodes with indegree of 0, insert temporary edge (S_min, v) with delta=0
  --   for all nodes with outdegree of 0, insert temporary edge (v, S_max) with delta=0
  
  -- classify edges as tree/forward, cross and back edges using a DFS traversal
  local tree_or_forward_edges, cross_edges, back_edges = algorithms.classify_edges(self.graph)

  -- reverse the back edges in order to make the graph acyclic
  for edge in table.value_iter(back_edges) do
    Sys:log('reverse back edge ' .. tostring(edge))
    edge.reversed = true
  end
end



function GansnerKNVLayered:postprocess()
  -- restore all reversed back edges so that, in the final graph, all
  -- edges appear with the direction specified by the user
  for edge in table.value_iter(self.graph.edges) do
    edge.reversed = false
  end
end



function GansnerKNVLayered:rankNodes()
  -- construct feasible tree of tight edges
  self:constructFeasibleTree()

  -- iteratively replace edges with negative cut values 
  -- with non-tree edges (chosen by minimum slack)
  local leave_edge = self:findNegativeCutEdge()
  while leave_edge do
    local enter_edge = self:findReplacementEdge(leave_edge)
    
    assert(enter_edge, 'no non-tree edge replace ' .. tostring(edge) .. ' could be found')

    Sys:log('replace negative cut edge ' .. tostring(leave_edge) .. ' with ' .. tostring(enter_edge))
    dump_tree(self.tree, 'tree before replacing edges')
    self:dumpRanking('', 'ranking before replacing edges')

    -- exchange leave_edge and enter_edge in the tree, updating
    -- the ranks and cut values of all nodes
    self:exchangeTreeEdges(leave_edge, enter_edge)
    
    -- find the next tree edge with a negative cut value, if 
    -- there are any left
    leave_edge = self:findNegativeCutEdge()
  end

  -- move nodes to feasible ranks with the least number of nodes
  -- in order to avoid crowding and to improve the overall aspect 
  -- ratio of the drawing
  self:balanceRanks()

  -- normalize by setting the least rank to zero
  self.ranking:normalizeRanks()
  self:dumpRanking('  ', 'ranking after normalization')
end



function GansnerKNVLayered:balanceRanks()
  Sys:log('balancing the ranks:')

  -- node to in/out weight mappings
  local in_weight = {}
  local out_weight = {}
  
  -- node to lowest/highest possible rank mapping
  local min_rank = {}
  local max_rank = {}

  -- compute the in and out weights of each node
  for node in table.value_iter(self.graph.nodes) do
    -- assume there are no restrictions on how to rank the node
    min_rank[node], max_rank[node] = self.ranking:getRankRange()

    for edge in table.value_iter(node:getIncomingEdges()) do
      -- accumulate the weights of all incoming edges
      in_weight[node] = (in_weight[node] or 0) + edge.weight
      
      -- update the minimum allowed rank (which is the maximum of
      -- the ranks of all parent neighbours plus the minimum level 
      -- separation caused by the connecting edges)
      local neighbour = edge:getNeighbour(node)
      local neighbour_rank = self.ranking:getRank(neighbour)
      min_rank[node] = math.max(min_rank[node], neighbour_rank + edge.minimum_levels)
    end
    
    for edge in table.value_iter(node:getOutgoingEdges()) do
      -- accumulate the weights of all outgoing edges
      out_weight[node] = (out_weight[node] or 0) + edge.weight

      -- update the maximum allowed rank (which is the minimum of
      -- the ranks of all child neighbours minus the minimum level
      -- sparation caused by the connecting edges)
      local neighbour = edge:getNeighbour(node)
      local neighbour_rank = self.ranking:getRank(neighbour)
      max_rank[node] = math.min(max_rank[node], neighbour_rank - edge.minimum_levels)
    end

    -- check whether the in- and outweight is the same
    if in_weight[node] == out_weight[node] then
      Sys:log('  feasible ranks of ' .. node.name .. ' are ' .. min_rank[node] .. ',...,' .. max_rank[node])

      -- check which of the allowed ranks has the least number of nodes
      local min_nodes_rank = min_rank[node]
      for n = min_rank[node] + 1, max_rank[node] do
        if #self.ranking:getNodes(n) < #self.ranking:getNodes(min_nodes_rank) then
          min_nodes_rank = n
        end
      end

      -- only move the node to the rank with the least number of nodes
      -- if it differs from the current rank of the node
      if min_nodes_rank ~= self.ranking:getRank(node) then
        self.ranking:setRank(node, min_nodes_rank)
      end

      Sys:log('  move ' .. node.name .. ' to rank ' .. self.ranking:getRank(node))
    end
  end
end



function GansnerKNVLayered:exchangeTreeEdges(leave_edge, enter_edge)
  Sys:log('exchange tree edge ' .. tostring(leave_edge) .. ' with ' .. tostring(enter_edge))

  self:rerankBeforeReplacingEdge(leave_edge, enter_edge)

  local cut_value = leave_edge.cut_value
  local head = enter_edge:getHead().tree_node
  local tail = enter_edge:getTail().tree_node
  
  local ancestor = self:updateCutValuesUpToCommonAncestor(tail, head, cut_value, true)
  local other_ancestor = self:updateCutValuesUpToCommonAncestor(head, tail, cut_value, false)

  assert(ancestor == other_ancestor)

  self.tree:deleteEdge(leave_edge)

  local edge_copy = enter_edge:copy()
  edge_copy.original_edge = enter_edge
  enter_edge.tree_edge = edge_copy

  edge_copy.cut_value = -cut_value

  for node in table.value_iter(enter_edge.nodes) do
    local node_copy 
    
    if node.tree_node then
      node_copy = node.tree_node
    else
      node_copy = node:copy()
      node_copy.original_node = node
      node.tree_node = node_copy
    end

    self.tree:addNode(node_copy)

    edge_copy:addNode(node_copy)
  end

  self.tree:addEdge(edge_copy)

  dump_tree(self.tree, 'tree after exchanging edges')

  self:calculateDFSRange(ancestor, self.parent_edge[ancestor], self.low[ancestor])
end



function GansnerKNVLayered:updateCutValuesUpToCommonAncestor(v, w, cut_value, dir)
  Sys:log('update cut values from ' .. v.name .. ' up to common ancestor of ' .. v.name .. ' and ' .. w.name)

  while not self:inTailComponentOf(w, v) do
    Sys:log('  ' .. w.name .. ' is in head component of ' .. v.name)

    local edge = self.parent_edge[v]

    Sys:log('    parent edge is ' .. tostring(edge))
  
    if edge:isTail(v) then
      d = dir
    else
      d = not dir
    end

    Sys:log('    old cut value of ' .. tostring(edge) .. ' = ' .. edge.cut_value)

    if d then
      edge.cut_value = edge.cut_value + cut_value
    else
      edge.cut_value = edge.cut_value - cut_value
    end

    Sys:log('    new cut value of ' .. tostring(edge) .. ' = ' .. edge.cut_value)

    if self.lim[edge:getTail()] > self.lim[edge:getHead()] then
      v = edge:getTail()
    else
      v = edge:getHead()
    end

    Sys:log('    continue with ' .. v.name)
  end

  return v
end



function GansnerKNVLayered:rerankBeforeReplacingEdge(leave_edge, enter_edge)
  local delta = self:edgeSlack(enter_edge)
  Sys:log('  delta = ' .. delta)

  local stack = {}
  local delta_stack = {}

  function push(node, delta)
    table.insert(stack, node)
    table.insert(delta_stack, delta)
  end

  function pop()
    return table.remove(stack), table.remove(delta_stack)
  end

  if delta >= 0 then
    local tail = leave_edge:getTail()
    local s = #tail.edges
    
    Sys:log('  s = ' .. s)

    if s == 1 then
      push(tail, delta)
    else
      local head = leave_edge:getHead()
      s = #head.edges

      if s == 1 then
        push(head, -delta)
      else
        if lim[tail] < lim[head] then
          push(tail, delta)
        else
          push(head, -delta)
        end
      end
    end
  end

  while #stack > 0 do
    local node, delta = pop()

    Sys:log('  rerank ' .. node.name .. ', delta = ' .. delta)

    self:dumpRanking('   ', 'ranks before reranking')

    local rank = self.ranking:getRank(node.original_node)
    self.ranking:setRank(node.original_node, rank - delta)

    self:dumpRanking('   ', 'ranks after reranking')

    local out_edges = node:getOutgoingEdges()
    local in_edges = node:getIncomingEdges()
    local edges = table.merge_values(out_edges, in_edges)

    for edge in table.value_iter(edges) do
      local other = edge:getNeighbour(node)
      if edge ~= self.parent_edge[node] then
        push(other, delta)
      end
    end
  end
end



function GansnerKNVLayered:dumpRanking(prefix, title)
  local ranks = self.ranking:getRanks()
  Sys:log(prefix .. title)
  for rank, nodes in pairs(ranks) do
    local str = prefix .. '  rank ' .. rank .. ':'
    local str = table.combine_values(nodes, function (str, node)
      return str .. ' ' .. node.name .. '(' .. self.ranking:getRankPosition(node) .. ')'
    end, str)
    Sys:log(str)
  end
end



function GansnerKNVLayered:findReplacementEdge(leave_edge)
  local head = leave_edge:getHead()
  local tail = leave_edge:getTail()
  local v = nil
  local outsearch = false

  --Sys:log('find replacement edge for ' .. tostring(leave_edge))

  if self.lim[tail] < self.lim[head] then
    v = tail
    outsearch = false
  else
    v = head
    outsearch = true
  end

  local enter_edge = nil

  local stack = {}
  local direction_stack = {}

  local function push(node, direction)
    table.insert(stack, node)
    table.insert(direction_stack, direction)
  end

  local function pop()
    return table.remove(stack), table.remove(direction_stack)
  end

  push(v, 'out')

  while #stack > 0 do
    local node, direction = pop()
    --Sys:log('  visit ' .. node.name .. ', direction ' .. direction)

    if direction == 'out' then
      local out_edges = node.original_node:getOutgoingEdges()

      for edge in table.value_iter(out_edges) do
        local edge_head = edge:getHead()

        if not edge.tree_edge then
          if not self:inTailComponentOf(edge_head.tree_node, v) then
            local slack = self:edgeSlack(edge)
            if not enter_edge or slack < self:edgeSlack(enter_edge) then
              enter_edge = edge
            end
          end
        else
          local edge_tail = edge:getTail(edge)
          if lim[edge_tail.tree_node] < lim[node] then
            push(edge_tail.tree_node, 'in')
          end
        end
      end
    else
      --Sys:log('  TODO handle \'in\' direction')
    end
  end

  return enter_edge
end



function GansnerKNVLayered:isIncidentToTree(edge)
  local incident = false
  if not edge.tree_edge then
    local head = edge:getHead()
    local tail = edge:getTail()

    if head.tree_node and not tail.tree_node then
      incident = true
    elseif tail.tree_node and not head.tree_node then
      incident = true
    end
  end
  return incident
end



function GansnerKNVLayered:constructFeasibleTree()
  self:computeInitialRanking()

  self:dumpRanking('', 'initial ranking')

  -- find a maximal tree of tight edges in the graph
  self.tree = self:findTightTree()
  while #self.tree.nodes < #self.graph.nodes do
    dump_tree(self.graph, 'input graph')
    dump_tree(self.tree, 'incomplete feasible tree')

    -- find a non-tree edge e incident to the tree, with a minimal amount of slack
    -- delta = slack(e)
    -- if incident node is head of e then delta = -delta end
    -- for v in tree do v.rank = v.rank + delta
    
    Sys:log('find non-tree edge with minimal slack:')

    for node in table.value_iter(self.graph.nodes) do
      local out_edges = node:getOutgoingEdges()
      for edge in table.value_iter(out_edges) do
        --Sys:log('  check if ' .. tostring(edge) .. ' is incident to the tree')
        if self:isIncidentToTree(edge) then
          --Sys:log('    it is')
          if not min_slack_edge or self:edgeSlack(edge) < self:edgeSlack(min_slack_edge) then
            min_slack_edge = edge
          end
        end
      end
    end

    Sys:log('  min_slack_edge = ' .. tostring(min_slack_edge))

    if min_slack_edge then
      local delta = self:edgeSlack(min_slack_edge)

      --Sys:log('  delta = ' .. delta)

      if delta > 0 then
        local head = min_slack_edge:getHead()
        local tail = min_slack_edge:getTail()

        if head.tree_node then
          delta = -delta
        end

        Sys:log('  delta = ' .. delta)

        for node in table.value_iter(self.tree.nodes) do
          local rank = self.ranking:getRank(node.original_node)
          Sys:log('  set rank of ' .. node.name .. ' from ' .. rank .. ' to ' .. rank + delta)
          self.ranking:setRank(node.original_node, rank + delta)
          self:dumpRanking('    ', 'ranking after that')
        end

        self.ranking:normalizeRanks()
      end
    end

    self.tree = self:findTightTree()
    
    dump_tree(self.tree, '(possibly incomplete) feasible tree after making ' .. tostring(min_slack_edge) .. ' tight')
    Sys:log('slack(' .. tostring(min_slack_edge) .. ') = ' .. self:edgeSlack(min_slack_edge))
    self:dumpRanking('', 'ranking after adding a non-tree edge with minimal slack to the tree')
  end

  self:initializeCutValues()
end



function GansnerKNVLayered:findTightTree(ranks)
  --Sys:log('find tight tree:')

  -- stack of nodes to visit next
  local stack = {}

  -- convenience functions for managing the queue
  function push(node) table.insert(stack, node) end
  function pop() return table.remove(stack) end

  local tree = nil

  -- construct a spanning tree for the subgraph reachable from
  -- each of the nodes in the underlying undirected graph, stop
  -- as soon as we have found one such spanning tree that is 
  -- non-empty
  for node in table.value_iter(self.graph.nodes) do
    --Sys:log('  test with start node ' .. node.name)

    -- create an empty spanning tree
    tree = Graph:new()

    -- create a mapping from original to copied nodes
    local tree_nodes = {}

    -- copy all nodes into the tree
    for node in table.value_iter(self.graph.nodes) do
      -- create a copy of the node
      local copy = node:copy()
      copy.original_node = node
      node.tree_node = copy

      -- remember the copy
      tree_nodes[node] = copy

      -- add the copied node to the tree
      tree:addNode(copy)
    end

    -- reset the stack
    stack = {}

    -- reset the finished flag
    local finished = false

    -- add the node to the queue
    push(node)

    -- perform a depth-first search in the underlying undirected graph
    while not finished and #stack > 0 do
      -- fetch the next node from the DFS queue
      local node = pop()
      local tree_node = tree_nodes[node]

      --Sys:log('    visit ' .. node.name)

      -- iterate over all outgoing edges
      for edge in table.value_iter(node:getOutgoingEdges()) do
        local neighbour = edge:getNeighbour(node)
        local tree_neighbour = tree_nodes[neighbour]

        --Sys:log('      edge to neighbour ' .. neighbour.name .. ' has slack ' .. self:edgeSlack(edge))

        if not tree_neighbour.marked and self:edgeSlack(edge) == 0 then
          --Sys:log('          queue ' .. neighbour.name)

          -- add the edge to the tree
          local edge_copy = edge:copy()
          edge_copy.original_edge = edge
          edge.tree_edge = edge_copy
          edge_copy:addNode(tree_node)
          edge_copy:addNode(tree_neighbour)
          tree:addEdge(edge_copy)

          -- mark the two nodes
          tree_node.marked = true
          tree_neighbour.marked = true

          -- add the neighbour to the queue
          push(neighbour)
          
          -- stop if we have a valid spanning tree
          if #tree.edges == #self.graph.nodes - 1 then
            finished = true
            break
          end
        end
      end

      -- iterate over all incoming edges
      for edge in table.value_iter(node:getIncomingEdges()) do
        local neighbour = edge:getNeighbour(edge)
        local tree_neighbour = tree_nodes[neighbour]

        --Sys:log('      edge from neighbour ' .. neighbour.name .. ' has slack ' .. self:edgeSlack(edge))

        if not tree_neighbour.marked and self:edgeSlack(edge) == 0 then
          --Sys:log('        queue ' .. neighbour.name)

          -- add the edge to the tree
          local edge_copy = edge:copy()
          edge_copy.original_edge = edge
          edge.tree_edge = edge_copy
          edge_copy:addNode(tree_neighbour)
          edge_copy:addNode(tree_node)
          tree:addEdge(edge_copy)

          -- mark the two nodes
          tree_node.marked = true
          tree_neighbour.marked = true

          -- add the neighbour to the queue
          push(neighbour)
          
          -- stop if we have a valid spanning tree
          if #tree.edges == #self.graph.nodes - 1 then
            finished = true
            break
          end
        end
      end
    end

    -- remove all non-marked nodes from the tree
    table.remove_values(tree.nodes, function (node)
      if not node.marked then
        node.original_node.tree_node = nil
        return true
      else
        return false
      end
    end)

    -- check if we have a valid spanning tree
    if finished or #tree.edges == #self.graph.nodes - 1 then
      dump_tree(self.graph, 'original graph')
      dump_tree(tree, 'tight tree')
      -- return the first spanning tree we can find
      return tree
    end
  end

  return tree
end



function GansnerKNVLayered:edgeSlack(edge)
  local rank1 = self.ranking:getRank(edge.nodes[1])
  local rank2 = self.ranking:getRank(edge.nodes[2])
  local length = math.abs(rank2 - rank1)
  return length - edge.minimum_levels
end



---
-- DFS algorithm that calculates post-order traversal indices and parent edges.
--
-- This algorithm performs a depth-first search in a directed or undirected
-- graph. For each node it calculates the node's post-order traversal index, the
-- minimum post-order traversal index of its descendants as well as the edge by
-- which the node was reached in the depth-first traversal.
--
function GansnerKNVLayered:calculateDFSRange(root, edge_from_parent, lowest)
  -- list of nodes to be visited next
  local stack = {}

  -- state information for the nodes
  local discovered = {}
  local visited = {}
  local completed = {}

  -- convenience functions to manage the queue
  function push(node) table.insert(stack, node) end
  function pop() return table.remove(stack) end
  function peek() return stack[#stack] end

  -- allocate variables for the range information
  local parent_edge = {}
  local lim = {}
  local low = {}
  local traversal_index = 0

  -- set range information for the root node
  parent_edge[root] = edge_from_parent
  lim[root] = lowest or 1
  low[root] = lowest or 1

  --- queue the root node
  push(root)
  discovered[root] = true

  -- perform the depth-first search
  while #stack > 0 do
    local node = peek()

    if visited[node] then
      completed[node] = true
      pop()

      local out_edges = node:getOutgoingEdges()
      local in_edges = node:getIncomingEdges()
      local edges = table.reverse_values(table.merge_values(out_edges, in_edges))

      -- remove edges to nodes already completed
      edges = table.filter_values(edges, function (edge)
        return completed[edge:getNeighbour(node)]
      end)

      -- assign post-order traversal number
      lim[node] = traversal_index + 1
      traversal_index = traversal_index + 1

      if #edges == 0 then
        low[node] = lim[node]
      else
        low[node] = table.combine_values(edges, function (value, edge)
          local neighbour = edge:getNeighbour(node)
          return math.min(value, low[neighbour])
        end, #self.tree.nodes)
      end

    else
      visited[node] = true

      local in_edges = node:getIncomingEdges()
      local out_edges = node:getOutgoingEdges()
      
      local edges = table.reverse_values(table.merge_values(out_edges, in_edges))

      for edge in table.value_iter(edges) do
        local neighbour = edge:getNeighbour(node)
        if not discovered[neighbour] then
          push(neighbour)
          parent_edge[neighbour] = edge
          discovered[neighbour] = true
        end
      end
    end
  end

  return lim, low, parent_edge
end



function GansnerKNVLayered:initializeCutValues()
  -- calculate depth-first search tree information for fast
  -- checks of whether a node lies in the head or tail component
  -- of a split-up edge
  self.lim, self.low, self.parent_edge = self:calculateDFSRange(self.tree.nodes[1])

  --for key, val in pairs(self.lim)do
  --  Sys:log('node ' .. key.name .. ' low/lim = ' .. self.low[key] .. '/' .. self.lim[key])
  --end

  -- list of nodes to be visited next
  local stack = {}

  -- state information for nodes in the DFS search
  local discovered = {}
  local visited = {}
  local completed = {}

  -- convenience functions to manage the DFS stack
  function push(node) table.insert(stack, node) end
  function pop() return table.remove(stack) end
  function peek() return stack[#stack] end

  --- push the root node to the stack
  push(self.tree.nodes[1])
  discovered[self.tree.nodes[1]] = true

  -- perform the depth-first search
  while #stack > 0 do
    local node = peek()

    if visited[node] then
      --Sys:log('complete ' .. node.name)

      completed[node] = true
      pop()

      if self.parent_edge[node] then
        self:updateCutValue(self.parent_edge[node])
      end
    else
      --Sys:log('visit ' .. node.name)

      visited[node] = true

      local in_edges = node:getIncomingEdges()
      local out_edges = node:getOutgoingEdges()
      
      local edges = table.reverse_values(table.merge_values(out_edges, in_edges))

      for edge in table.value_iter(edges) do
        local neighbour = edge:getNeighbour(node)
        
        if self.parent_edge[node] ~= edge and not discovered[neighbour] then
          push(neighbour)
          discovered[neighbour] = true
        end
      end
    end
  end

  --Sys:log('cut values:')
  --for edge in table.value_iter(self.tree.edges) do
  --  Sys:log('  ' .. tostring(edge) .. ' cut value ' .. edge.cut_value)
  --end
end



function GansnerKNVLayered:inTailComponentOf(node, v)
  return (self.low[v] <= self.lim[node]) and (self.lim[node] <= self.lim[v])
end



function GansnerKNVLayered:updateCutValue(tree_edge)
  --Sys:log('update cut value of ' .. tostring(tree_edge))

  local v = nil
  if self.parent_edge[tree_edge:getTail()] == tree_edge then
    v = tree_edge:getTail()
    dir = 1
  else
    v = tree_edge:getHead()
    dir = -1
  end

  --Sys:log('  v = ' .. v.name)
  --Sys:log('  dir = ' .. dir)

  local sum = 0

  local out_edges = v.original_node:getOutgoingEdges()
  local in_edges = v.original_node:getIncomingEdges()
  local edges = table.merge_values(out_edges, in_edges)

  for edge in table.value_iter(edges) do
    --Sys:log('  xval(' .. tostring(edge) .. ', v = ' .. v.name .. ', dir = ' .. dir)

    local other = edge:getNeighbour(v.original_node)
    --Sys:log('    other = ' .. other.name)

    local f = 0
    local rv = 0

    if not self:inTailComponentOf(other.tree_node, v) then
      f = 1
      rv = edge.weight
    else
      f = 0

      if edge.tree_edge then
        rv = edge.tree_edge.cut_value
      else
        rv = 0
      end

      rv = rv - edge.weight
    end

    --Sys:log('    f = ' .. f)
    --Sys:log('    rv = ' .. rv)

    local d = 0

    if dir > 0 then
      if edge:isHead(v.original_node) then
        d = 1
      else
        d = -1
      end
    else
      if edge:isTail(v.original_node) then
        d = 1
      else
        d = -1
      end
    end

    --Sys:log('    d = ' .. d)

    if f > 0 then
      d = -d
      --Sys:log('    d = ' .. d)
    end

    if d < 0 then
      rv = -rv
    end

    --Sys:log('    rv = ' .. rv)

    sum = sum + rv
  end

  tree_edge.cut_value = sum
  --Sys:log('  cutvalue = ' .. sum)
end



function GansnerKNVLayered:nextSearchIndex()
  local index = 1
    
  -- avoid tree edge index out of bounds by resetting the search index 
  -- as soon as it leaves the range of edge indices in the tree
  if self.search_index > #self.tree.edges then
    self.search_index = 1
    index = 1
  else
    index = self.search_index
    self.search_index = self.search_index + 1
  end

  return index
end



function GansnerKNVLayered:findNegativeCutEdge()
  local minimum_edge = nil

  for n in iter.times(#self.tree.edges) do
    local index = self:nextSearchIndex()
    Sys:log('search index ' .. index)

    local edge = self.tree.edges[index]

    if edge.cut_value < 0 then
      if minimum_edge then
        if minimum_edge.cut_value > edge.cut_value then
          minimum_edge = edge
        end
      else
        minimum_edge = edge
      end
    end
  end

  return minimum_edge
end



function GansnerKNVLayered:computeInitialRanking()
  -- queue for nodes to rank next
  local queue = {}

  -- number mapping that counts the number of ranked incoming 
  -- neighbours of each node
  local ranked_neighbours = {}

  -- convenience functions for managing the queue
  local function enqueue(node) table.insert(queue, node) end
  local function dequeue() return table.remove(queue, 1) end

  -- function to move unranked nodes to the queue if they have no
  -- unscanned incoming edges
  local function update_queue(node)
    -- check all nodes yet to be ranked
    for edge in table.value_iter(node:getOutgoingEdges()) do
      local neighbour = edge:getNeighbour(node)

      -- increment the number of ranked incoming neighbours of the neighbour node
      ranked_neighbours[neighbour] = (ranked_neighbours[neighbour] or 0) + 1

      -- check whether all incoming edges have been scanned
      if ranked_neighbours[neighbour] >= neighbour:getInDegree() then
        -- we have no unscanned incoming edges, queue the node now
        enqueue(neighbour)
      end
    end
  end

  -- reset the two-dimensional mapping from ranks to lists 
  -- of corresponding nodes
  self.ranks = {}
  self.ranking:reset()

  -- invalidate the ranks of all nodes
  for node in table.value_iter(self.graph.nodes) do
    node.rank = -1
  end

  -- add all sinks to the queue
  for node in table.value_iter(self.graph.nodes) do
    if node:getInDegree() == 0 then
      enqueue(node)
      ranked_neighbours[node] = 0
    end
  end

  -- run long as there are nodes to be ranked
  while #queue > 0 do
    -- fetch the next unranked node from the queue
    local node = dequeue()
    -- get a list of its incoming edges
    local in_edges = node:getIncomingEdges()

    -- determine the minimum possible rank for the node
    local rank = table.combine_values(in_edges, function (rank, edge)
      local neighbour = edge:getNeighbour(node)
      if neighbour.rank then
        -- the minimum possible rank is the maximum of all neighbour ranks plus
        -- the corresponding edge lengths
        rank = math.max(rank, neighbour.rank + edge.minimum_levels)
      end
      return rank
    end, 1)

    -- rank the node
    node.rank = rank

    -- add the node to the two-dimensional rank mapping
    self.ranks[node.rank] = self.ranks[node.rank] or {}
    table.insert(self.ranks[node.rank], node)

    -- rank the node
    self.ranking:setRank(node, rank)

    -- queue neighbours of nodes for which all incoming edges have
    -- been scanned
    --
    -- note that we don't need to mark the node's outgoing edges 
    -- as scanned prior to this, because this is equivalent to checking
    -- whether the node has already been ranked or not
    update_queue(node)
  end
end



function GansnerKNVLayered:reduceEdgeCrossings()
  self:dumpRanking('', 'ranking after creating dummy nodes')

  self:computeInitialRankOrdering()

  local best_ranking = self.ranking:copy()

  for iteration in iter.times(24) do
    local direction = (iteration % 2 == 0) and 'down' or 'up'

    self:orderByWeightedMedian(direction)
    self:transpose(direction)

    Sys:log('self.ranking = ' .. tostring(self.ranking) .. ', best_ranking = ' .. tostring(best_ranking))

    if self:countRankCrossings(self.ranking) < self:countRankCrossings(best_ranking) then
      best_ranking = self.ranking:copy()
    end
  end

  self.ranking = best_ranking:copy()
end



function GansnerKNVLayered:computeInitialRankOrdering()
  Sys:log('compute initial rank ordering:')

  -- DFS stack of nodes to be visited next
  local stack = {}

  -- state information for nodes in the DFS search
  local visited = {}

  -- convenience functions for managing the DFS stack
  local function push(node) table.insert(stack, node) end
  local function pop() return table.remove(stack) end

  -- clear the rank sets
  self.ranks = {}

  -- visit all sourcs of the graph first
  for node in table.value_iter(self.graph.nodes) do
    if node:getInDegree() == 0 then
      push(node)
      visited[node] = true
    end
  end

  -- reverse the stack order so that the source with lowest 
  -- index is visited first
  stack = table.reverse_values(stack)

  while #stack > 0 do
    local node = pop()

    --Sys:log('  visit ' .. node.name)

    self.ranks[node.rank] = self.ranks[node.rank] or {}
    table.insert(self.ranks[node.rank], node)
    node.rank_position = #self.ranks[node.rank]

    --Sys:log('    append to rank ' .. self.ranking:getRank(node))
    --Sys:log('      at pos ' .. self.ranking:getRankSize(self.ranking:getRank(node)))
    local rank = self.ranking:getRank(node)
    local pos = self.ranking:getRankSize(rank)
    self.ranking:setRankPosition(node, pos)

    for edge in table.value_iter(node:getOutgoingEdges()) do
      local neighbour = edge:getNeighbour(node)
      if not visited[neighbour] then
        push(neighbour)
        visited[neighbour] = true
      end
    end
  end

  self:dumpRanking('  ', 'ranking after initial ordering')
end



function GansnerKNVLayered:orderByWeightedMedian(direction)
  Sys:log('order by weighted median (' .. direction .. ')')

  local median = {}

  local function compare_median(node, other)
    return (median[node] - median[other]) > 0
  end

  self:dumpRanking('  ', ' ranks before applying the median')

  if direction == 'down' then
    local min_rank, max_rank = self.ranking:getRankRange()

    for rank = min_rank + 1, max_rank do
      median = {}
      for node in table.value_iter(self.ranking:getNodes(rank)) do
        median[node] = self:computeMedianPosition(node, rank-1)
      end
      -- TODO we need our own sorting mechanism here that
      -- (a) keeps fixed nodes in their positions
      -- (b) updates the rank_position member as nodes switch positions
      table.sort(self.ranking:getNodes(rank), compare_median)
    end
  else
    local min_rank, max_rank = self.ranking:getRankRange()

    for rank = max_rank-1, min_rank, -1 do
      median = {}
      for node in table.value_iter(self.ranking:getNodes(rank)) do
        median[node] = self:computeMedianPosition(node, rank+1)
      end
      -- TODO we need our own sorting mechanism here that
      -- (a) keeps fixed nodes in their positions
      -- (b) updates the rank_position member as nodes switch positions
      table.sort(self.ranking:getNodes(rank), compare_median)
    end
  end

  self:dumpRanking('  ', ' ranks after applying the median')
end



function GansnerKNVLayered:computeMedianPosition(node, prev_rank)
  --Sys:log('  compute median position of ' .. node.name .. ' (prev_rank = ' .. prev_rank .. '):')

  local in_edges = table.filter_values(node.edges, function (edge)
    return edge:getNeighbour(node).rank == prev_rank
  end)

  local positions = table.map_values(in_edges, function (edge)
    return edge:getNeighbour(node).rank_position
  end)

  table.sort(positions)

  --Sys:log('    positions = ' .. table.concat(positions, ', '))

  local median = math.ceil(#positions / 2)

  --Sys:log('    median = ' .. median)

  local position = -1

  if #positions > 0 then
    if #positions % 2 == 1 then
      position = positions[median]
    elseif #positions == 2 then
      return (positions[1] + positions[2]) / 2
    else
      local left = positions[median-1] - positions[1]
      local right = positions[#positions] - positions[median]
      --Sys:log('    left = ' .. left .. ', right = ' .. right)
      position = (positions[median-1] * right + positions[median] * left) / (left + right)
    end
  end

  --Sys:log('    position = ' .. position)

  return position
end



function GansnerKNVLayered:transpose(sweep_direction)
  Sys:log('transpose (sweep direction ' .. sweep_direction .. ')')

  local function transpose_rank(rank)
    local improved = false

    for i = 1, #self.ranks[rank]-1 do
      local v = self.ranks[rank][i]
      local w = self.ranks[rank][i+1]

      local cn_vw = self:countNodeCrossings(v, w, sweep_direction)
      local cn_wv = self:countNodeCrossings(v, w, sweep_direction)

      if cn_vw > cn_wv then
        improved = true
        self:switchNodePositions(v, w)

        self:dumpRanking('    ', 'ranks after switching positions')
      end
    end

    return improved
  end

  local improved = false
  repeat
    if sweep_direction == 'down' then
      for rank = 1, #self.ranks-1 do
        improved = transpose_rank(rank)
      end
    else
      for rank = #self.ranks-1, 1, -1 do
        improved = transpose_rank(rank)
      end
    end
  until not improved
end



function GansnerKNVLayered:countNodeCrossings(left_node, right_node, sweep_direction)
  Sys:log('  count crossings of (' .. left_node.name .. ', ' .. right_node.name .. ') (sweep direction ' .. sweep_direction .. ')')

  local left_edges = {}
  local right_edges = {}

  if sweep_direction == 'down' then
    left_edges = left_node:getIncomingEdges()
    right_edges = right_node:getIncomingEdges()
  else
    left_edges = left_node:getOutgoingEdges()
    right_edges = right_node:getOutgoingEdges()
  end
  
  local crossings = 0

  for left_edge in table.value_iter(left_edges) do
    local left_neighbour = left_edge:getNeighbour(left_node)

    for right_edge in table.value_iter(right_edges) do
      local right_neighbour = right_edge:getNeighbour(right_node)

      Sys:log('    check crossing with (' .. left_neighbour.name .. ' at ' .. left_neighbour.rank_position .. ', ' .. right_neighbour.name .. ' at ' .. right_neighbour.rank_position .. ')')

      local neighbour_diff = right_neighbour.rank_position - left_neighbour.rank_position

      if neighbour_diff < 0 then
        Sys:log('      edges cross, crossings += 1')
        crossings = crossings + 1
      end
    end
  end

  Sys:log('    ' .. crossings .. ' crossings')

  return crossings
end



function GansnerKNVLayered:switchNodePositions(left_node, right_node)
  Sys:log('    switch positions of ' .. left_node.name .. ' and ' .. right_node.name)

  assert(left_node.rank == right_node.rank)
  assert(left_node.rank_position < right_node.rank_position)

  table.remove(self.ranks[left_node.rank], left_node.rank_position)
  table.insert(self.ranks[left_node.rank], left_node.rank_position, right_node)

  table.remove(self.ranks[left_node.rank], right_node.rank_position)
  table.insert(self.ranks[left_node.rank], right_node.rank_position, left_node)

  local left_pos = left_node.rank_position
  left_node.rank_position = right_node.rank_position
  right_node.rank_position = left_pos

  for n = 1, #self.ranks[left_node.rank] do
    assert(self.ranks[left_node.rank][n].rank_position == n)
  end
end



function GansnerKNVLayered:countRankCrossings(ranking)
  local crossings = 0

  local min_rank, max_rank = ranking:getRankRange()
  
  for rank = min_rank+1, max_rank do
    local nodes = ranking:getNodes(rank)
    for i = 1, #nodes-1 do
      local v = nodes[i]
      local w = nodes[i+1]

      local cn_vw = self:countNodeCrossings(v, w, 'down')

      crossings = crossings + cn_vw
    end
  end

  --for rank = 2, #ranks do
  --  for i = 1, #ranks[rank]-1 do
  --    local v = ranks[rank][i]
  --    local w = ranks[rank][i+1]

  --    local cn_vw = self:countNodeCrossings(v, w, 'down')

  --    crossings = crossings + cn_vw
  --  end
  --end

  return crossings
end



function GansnerKNVLayered:insertDummyNodes()
  -- enumerate dummy nodes using a globally unique numeric ID
  local dummy_id = 1

  -- keep track of the original edges removed
  self.original_edges = {}

  -- keep track of dummy nodes introduced
  self.dummy_nodes = {}

  for node in traversal.topological_sorting(self.graph) do
    local in_edges = node:getIncomingEdges()

    for edge in table.value_iter (in_edges) do
      local neighbour = edge:getNeighbour(node)
      local dist = node.rank - neighbour.rank

      if dist > 1 then
        local dummies = {}

        for i in iter.times(dist-1) do
          local rank = neighbour.rank + i

          local dummy = Node:new{
            pos = Vector:new({ 0, 0 }),
            rank = rank,
            name = 'dummy@' .. neighbour.name .. '@to@' .. node.name .. '@at@' .. rank,
          }
          
          dummy_id = dummy_id + 1

          self.graph:addNode(dummy)

          table.insert(self.ranks[dummy.rank], dummy)

          self.ranking:setRank(dummy, rank)

          table.insert(self.dummy_nodes, dummy)
          table.insert(edge.bend_nodes, dummy)

          table.insert(dummies, dummy)
        end

        table.insert(dummies, 1, neighbour)
        table.insert(dummies, #dummies+1, node)

        for i = 2, #dummies do
          local source = dummies[i-1]
          local target = dummies[i]

          local dummy_edge = Edge:new{direction = Edge.RIGHT, reversed = false}

          dummy_edge:addNode(source)
          dummy_edge:addNode(target)

          self.graph:addEdge(dummy_edge)
        end

        table.insert(self.original_edges, edge)
      end
    end
  end

  for edge in table.value_iter(self.original_edges) do
    self.graph:deleteEdge(edge)
  end

  dump_tree(self.graph, 'GRAPH WITH DUMMY NODES')
end



function GansnerKNVLayered:removeDummyNodes()
  -- delete dummy nodes
  for node in table.value_iter(self.dummy_nodes) do
    self.graph:deleteNode(node)
  end

  -- add original edge again
  for edge in table.value_iter(self.original_edges) do
    -- add edge to the graph
    self.graph:addEdge(edge)

    -- add edge to the nodes
    for node in table.value_iter(edge.nodes) do
      node:addEdge(edge)
    end

    -- convert bend nodes to bend points for TikZ
    for bend_node in table.value_iter(edge.bend_nodes) do
      local point = Vector:new(bend_node.pos.elements)
      table.insert(edge.bend_points, point)
    end

    if edge.reversed then
      edge.bend_points = table.reverse_values(edge.bend_points, edge.bend_points)
    end

    -- clear the list of bend nodes
    edge.bend_nodes = {}
  end

  dump_tree(self.graph, 'FINAL GRAPH')
end



function GansnerKNVLayered:computeCoordinates()
  -- TODO this is a temporary algorithm used for debugging
  
  for rank = 1, #self.ranks do
    local x = 0
    for node in table.value_iter(self.ranks[rank]) do
      node.pos:set{x = x * self.sibling_distance}
      x = x + 1
    end
  end

  for node in table.value_iter(self.graph.nodes) do
    node.pos:set{
      y = - node.rank * self.level_distance,
    }
  end
end



function GansnerKNVLayered:makeSplines()
end



function dump_tree(tree, name)
  Sys:log(name .. ':')
  --for node in table.value_iter(tree.nodes) do
  --  --Sys:log('  node ' .. node.name)
  --  --for edge in table.value_iter(node.edges) do
  --  --  Sys:log('    edge ' .. tostring(edge))
  --  --end
  --end
  for edge in table.value_iter(tree.edges) do
    Sys:log('  edge ' .. tostring(edge))
  end
end
