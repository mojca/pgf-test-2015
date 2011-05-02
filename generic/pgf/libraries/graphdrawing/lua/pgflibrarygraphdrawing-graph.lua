-- Copyright 2010 by Renée Ahrens, Olof Frahm, Jens Kluttig, Matthias Schulz, Stephan Schuster
-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/libraries/graphdrawing/lua/pgflibrarygraphdrawing-graph.lua,v 1.10 2011/05/02 03:36:23 jannis-pohlmann Exp $

-- This file defines a graph class, which later represents user created
-- graphs.

pgf.module("pgf.graphdrawing")



Graph = Box:new()
Graph.__index = Graph



--- Creates a new graph.
--
-- @param values  Values to override default graph settings.
--                The following parameters can be set:\par
--                |nodes|: The nodes of the graph.\par
--                |edges|: The edges of the graph.\par
--                |pos|: Initial position of the graph.\par
--                |options|: A table of node options passed over from \tikzname.
--
-- @return A newly-allocated graph.
--
function Graph:new(values)
  local defaults = {
    nodes = {},
    edges = {},
    pos = Position:new(),
    options = {},
  }
  setmetatable(defaults, Graph)
  local result = mergeTable(values, defaults)
  return result
end



--- Sets the graph option \meta{name} to \meta{value}.
--
-- @param name Name of the option to be changed.
-- @param value New value for the graph option \meta{name}.
--
function Graph:setOption(name, value)
  self.options[name] = value
end



--- Returns the value of the graph option \meta{name}.
--
-- @param name Name of the option.
--
-- @return The value of the graph option \meta{name} or |nil|.
--
function Graph:getOption(name)
  return self.options[name]
end



--- Merges the given options into the options of the graph.
--
-- @param options The options to be merged.
--
-- @see mergeTable
--
function Graph:mergeOptions(options)
  self.options = mergeTable(options, self.options)
end



--- Creates a shallow copy of a graph.
--
-- The nodes and edges of the original graph are not preserved in the copy.
--
-- @return A shallow copy of the graph.
--
function Graph:copy ()
  local result = copyTable(self, Graph:new())
  result.nodes = {}
  result.edges = {}
  result.root = nil
  return result
end



--- Adds a node to the graph.
--
-- @param node The node to be added.
--
function Graph:addNode(node)
  -- only add the node if it's not included in the graph yet
  if not self:findNode(node.name) then
    table.insert(self.nodes, node)
    
    if node.tex.maxY and node.tex.maxX and node.tex.minY and node.tex.minX then
      node.height = string.sub(node.tex.maxY, 0, string.len(node.tex.maxY)-2) 
                  - string.sub(node.tex.minY, 0, string.len(node.tex.minY)-2)

      node.width = string.sub(node.tex.maxX,0,string.len(node.tex.maxX)-2)
                 - string.sub(node.tex.minX,0,string.len(node.tex.minX)-2)
    end
    
    assert(node.height >= 0)
    assert(node.width >= 0)
  end
end



--- If possible, removes a node from the graph and returns it.
--
-- @param node The node to remove.
--
-- @return The removed node or |nil| if it was not found in the graph.
--
function Graph:removeNode(node)
  local index = table.find_index(self.nodes, function (other) 
    return other.name == node.name 
  end)
  if index then
    table.remove(self.nodes, index)
    return node
  else
    return nil
  end
end



--- If possible, looks up the node with the given name in the graph.
--
-- @param name Name of the node to look up.
--
-- @return The node with the given name or |nil| if it was not found in the graph.
--
function Graph:findNode(name)
  return self:findNodeIf(function (node) return node.name == name end)
end



--- Looks up the first node for which the function \meta{test} returns |true|.
--
-- @param test A function that takes one parameter (a |Node|) and returns 
--             |true| or |false|.
--
-- @return The first node for which \meta{test} returns |true|.
--
function Graph:findNodeIf(test)
  return table.find(self.nodes, test)
end



--- Like removeNode, but also deletes all adjacent edges of the removed node.
--
-- This function also removes the deleted adjacent edges from all neighbours
-- of the removed node.
--
-- @param node The node to be deleted together with its adjacent edges.
--
-- @return The removed node or |nil| if the node was not found in the graph.
--
function Graph:deleteNode(node)
  local node = self:removeNode(node)
  if node then
    for edge in table.value_iter(node.edges) do
      self:removeEdge(edge)
      for other_node in table.value_iter(edge.nodes) do
        if other_node.name ~= node.name then
          other_node:removeEdge(edge)
        end
      end
    end
    node.edges = {}
  end
  return node
end



--- Adds an edge to the graph.
--
-- @param edge The edge to be added.
--
function Graph:addEdge(edge)
  if not table.find(self.edges, function (other) return other == edge end) then
    table.insert(self.edges, edge)
  end
end



--- If possible, removes an edge from the graph and returns it.
--
-- @param edge The edge to be removed.
--
-- @return The removed edge or |nil| if it was not found in the graph.
--
function Graph:removeEdge(edge)
  local index = table.find_index(self.edges, function (other) return other == edge end)
  if index then
    table.remove(self.edges, index)
    return edge
  else
    return nil
  end
end



--- Like removeEdge, but also removes the edge from its adjacent nodes.
--
-- @param edge The edge to be deleted.
--
-- @return The removed edge or |nil| if it was not found in the graph.
--
function Graph:deleteEdge(edge)
  local edge = self:removeEdge(edge)
  if edge then
    for node in table.value_iter(edge.nodes) do
      node:removeEdge(edge)
    end
  end
  return edge
end



--- Creates and adds a new edge to the graph. 
--
-- @param nodeA       The first node of the new edge.
-- @param nodeB       The second node of the new edge.
-- @param direction   The direction of the new edge. Possible values are
--                    |Edge.UNDIRECTED|, |Edge.LEFT|, |Edge.RIGHT|, |Edge.BOTH|
--                    and |Edge.NONE| (for invisible edges).
-- @param edgenodes   A string of \tikzname\ edge nodes that needs to be passed 
--                    back to the \TeX layer unmodified.
-- @param options     The options of the new edge.
-- @param tikzoptions A table of \tikzname\ options to be used by graph drawing
--                    algorithms to treat the edge in special ways.
--
-- @return The newly created edge.
--
function Graph:createEdge(nodeA, nodeB, direction, edgenodes, options, tikzoptions)
  local edge = Edge:new{
    direction = direction, 
    edge_nodes = edge_nodes,
    options = options, 
    tikz_options = tikzoptions
  }
  edge:addNode(nodeA)
  edge:addNode(nodeB)
  self:addEdge(edge)
  return edge
end



--- Auxiliary function to walk a graph. Does nothing if no nodes exist.
--
-- @see walkDepth, walkBreadth
--
-- @param root        The first node to be visited.  If nil, chooses some node.
-- @param visited     Set of already visited nodes and edges.
--                    |visited[v] == true| indicates that the node or edge |v| 
--                    has already been visited.
-- @param removeIndex A numeric value or |nil| that defines the order in which nodes
--                    and edges are visited while traversing the graph. |nil| results
--                    in queue behavior, |1| in stack behavior.
--
function Graph:walkAux(root, visited, removeIndex)
  root = root or self.nodes[1]
  if not root then return end
  
  visited = visited or {}
  visited[root] = true

  local nodeQueue = {root}
  local edgeQueue = {}

  local function insertVisited(queue, object)
    if not visited[object] then
      table.insert(queue, 1, object)
      visited[object] = true
    end
  end

  local function remove(queue)
    return table.remove(queue, removeIndex or #queue)
  end

  return function ()
    while #edgeQueue > 0 do
      local currentEdge = remove(edgeQueue)
      for node in table.value_iter(currentEdge.nodes) do
        insertVisited(nodeQueue, node)
      end
      return currentEdge
    end
    while #nodeQueue > 0 do
      local currentNode = remove(nodeQueue)
      for edge in table.value_iter(currentNode.edges) do
        insertVisited(edgeQueue, edge)
      end
      return currentNode
    end
    return nil
  end
end



--- Returns an iterator to walk the graph in a depth-first traversal.
--
-- The iterator returns all edges and nodes one at a time. In case only the
-- nodes are of interest, a filter function like |iter.filter| can be used
-- to ignore edges.
--
-- @see iter.filter
--
-- @param root    The first node to be visited.  If nil, chooses some node.
-- @param visited Set of already visited nodes and edges.
--                |visited[v] == true| indicates that the node or edge |v| 
--                has already been visited.
--
function Graph:walkDepth(root, visited)
  return self:walkAux(root, visited, 1)
end



--- Returns an iterator to walk the graph in a breadth-first traversal.
--
-- The iterator returns all edges and nodes one at a time. In case only the
-- nodes are of interest, a filter function like |iter.filter| can be used
-- to ignore edges.
--
-- @see iter.filter
--
-- @param root    The first node to be visited.  If nil, chooses some node.
-- @param visited Set of already visited nodes and edges.
--                |visited[v] == true| indicates that the node or edge |v| 
--                has already been visited.
--
function Graph:walkBreadth(root, visited)
   return self:walkAux(root, visited)
end



--- Returns a subgraph.
--
-- The resulting subgraph begins at the node root, excludes all nodes and 
-- edges that are marked as visited.
--
-- @param root    Root node where the operation starts.
-- @param graph   Result graph object or |nil| if the original graph should
--                be used as the parent graph.
-- @param visited Set of already visited nodes/edges or |nil|. This set
--                will be modified so make sure not to use a table that
--                you want to remain untouched.
--
function Graph:subGraph(root, graph, visited)
  graph = graph or self:copy()
  visited = visited or {}
  
  -- translates old things to new things
  local translate = {}
  local nodes, edges = {}, {}
  for v in self:walkDepth(root, visited) do
    if v.__index == Node then
      table.insert(nodes, v)
    elseif v.__index == Edge then
      table.insert(edges, v)
    end
  end
  
  -- create new nodes (without edges)
  for node in values(nodes) do
    local copy = node:copy()
    graph:addNode(copy)
    assert(copy)
    translate[node] = copy
    graph.root = graph.root or copy
  end
  
  -- create new edges and adds them to graph and nodes
  for edge in values(edges) do
    local copy = edge:copy()
    local canAdd = true
    for v in values(edge.nodes) do
      local translated = translate[v]
      if not translated then
         canAdd = false
      end
    end
    if canAdd then
      for v in values(edge.nodes) do
        local translated = translate[v]
        graph:addNode(translated)
      end
      for node in values(copy.nodes) do
        node:addEdge(copy)
      end
      graph:addEdge(copy)
    end
  end
  
  return graph
end



--- Creates a new subgraph with \meta{parent} marked as visited. 
--
-- This function can be useful if the graph is a tree structure (and 
-- \meta{parent} is the parent node of \meta{root}).
--
-- @see subGraph
--
-- @param root   Root node where the operation starts.
-- @param parent Parent of the recursion step before.
-- @param graph  Result graph object or |nil| if the original graph should
--               be used as the parent graph.
--
function Graph:subGraphParent(root, parent, graph)
  local visited = {}
  visited[parent] = true
  
  -- mark edges with root and parent as visited
  for edge in table.value_iter(root.edges) do
    if edge:containsNode(root) and edge:containsNode(parent) then
      visited[edge] = true
    end
  end
  return self:subGraph(root, graph, visited)
end



--- Returns a string representation of this graph including all nodes and edges.
--
-- @ignore This should not appear in the documentation.
--
-- @return Graph as string.
--
function Graph:__tostring()
  local tmp = Graph.__tostring
  Graph.__tostring = nil
  local result = "Graph<" .. tostring(self) .. ">(("
  Graph.__tostring = tmp

  local first = true
  for node in values(self.nodes) do
    if first then first = false else result = result .. ", " end
    result = result .. tostring(node)
  end
  result = result .. "), ("
  first = true
  for edge in values(self.edges) do
    if first then first = false else result = result .. ", " end
    result = result .. tostring(edge)
  end

  return result .. "))"
end
