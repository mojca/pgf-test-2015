-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/model/pgf.gd.model.Arc.lua,v 1.1 2012/04/24 23:01:27 tantau Exp $


--- The Vertex class
--
-- A vertex object models a node of graphs. Each vertex can be an
-- element of any number of graphs (whereas an arc can only be an
-- element of a single graph). A node has the following fields by
-- default:
--
--   pos: A coordinate object that stores the position where the node should
--        be placed on the canvas. The main objective of graph drawing
--        algroithms is to update this coordinate.
--  hull: An array of coordinate that should be interpreted relative
--        to the pos field. They should describe a convex hull of the
--        node.
-- shape: A string describing the shape of the node (like "rectangle"
--        or "circle").
--  kind: A string describing the kind of the node. For instance, a
--        node of type "dummy" does not correspond to any real node in
--        the graph but is used by the graph drawing algorithm.
--  name: An optional string that is used as a textual representation
--        of the node.
--  
-- When a node is added to a digraph g, a new table is added as the
-- field [g] to the node. This table stores the incoming arcs and the
-- outgoing arcs, see the description of digraph, as well as an index
-- of the node in the digraph's vertices array.

local Vertex = {}
Vertex.__index = Vertex


-- Namespace

require("pgf.gd.model").Vertex = Vertex


-- Imports

local Coordinate = require "pgf.gd.model.Coordinate"


--- Creates a new vertex.
--
-- @param values  Values to override default node settings.
--                The following parameters can be set:
--                |name|: The name of the node. It is optional to define this.
--                |hull|: An array of coordinate objects. It will not be copied, but referenced.
--                |shape|: A string describing the shape.
--                |kind|: A kind like "node" or "dummy".
--                |pos|: Initial position of the node.
--
-- @return A newly allocated node.
--
function Vertex:new(values)
  local new = {
    name = values.name,
    hull = values.hull or { Coordinate:new(0,0) },
    shape = values.shape or "hull",
    kind = values.kind or "node",
    pos = values.pos or Coordinate:new(0,0)
  }
  setmetatable(new, Vertex)
  return new
end



--- Returns a string representation of an arc. This is mainly for debugging
--
-- @return The Arc as string.
--
function Vertex:__tostring()
  return self.name or tostring(self.hull)
end


-- Done

return Vertex