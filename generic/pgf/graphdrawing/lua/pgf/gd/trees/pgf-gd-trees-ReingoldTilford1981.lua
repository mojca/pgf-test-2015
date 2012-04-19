-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/trees/pgfgd-algorithm-TreeReingoldTilford1981.lua,v 1.3 2012/04/17 22:40:47 tantau Exp $



--- An implementation of the Reingold-Tilford algorithm
--
-- This implemenation follows the ideas outlined in
--
-- A. Brüggemann-Klein, D. Wood, Drawing trees nicely with TeX,
-- Electronic Publishing, 2(2), 101-115, 1989

local ReingoldTilford1981 = pgf.gd.new_algorithm_class {
  properties = {
    works_only_on_connected_graphs = true,
    needs_a_spanning_tree = true,
    growth_direction = 90,
  },
  graph_parameters = {
    extended_version = 'tree layout/missing nodes get space [boolean]',
    sigsep           = 'tree layout/significant sep [number]',
  }
}


-- Imports
local NodeDistances = require "pgf.gd.lib.NodeDistances"


function ReingoldTilford1981:run()
  
  local root = self.graph[self].spanning_tree_root

  self:precomputeDescendants(root, 1)
  self:computeHorizontalPosition(root)
  NodeDistances:arrangeLayersByBaselines(self, self.graph)

  -- Update x positions
  for _,n in ipairs(self.graph.nodes) do
    n.pos.x = n[self].x 
  end

end


function ReingoldTilford1981:precomputeDescendants(node, depth)
  node[self].descendants = { node }
  node[self].y = depth
  for _,c in ipairs(node[self].children) do
    self:precomputeDescendants(c, depth+1)
    for _,d in ipairs(c[self].descendants) do
      table.insert(node[self].descendants, d)
    end
  end
end



function ReingoldTilford1981:computeHorizontalPosition(node)
  
  local children = node[self].children

  node[self].x = 0

  local child_depth = node[self].y + 1

  if #children > 0 then
    -- First, compute positions for all children:
    for i=1,#children do
      self:computeHorizontalPosition(children[i])
    end
    
    -- Now, compute minimum distances and shift them
    local right_borders = {}

    for i=1,#children-1 do
      
      local local_right_borders = {}
      
      -- Advance "right border" of the subtree rooted at
      -- the i-th child
      for _,d in ipairs(children[i][self].descendants) do
	local y = d[self].y
	if self.extended_version or not (y > child_depth and d.kind == "dummy") then
	  if not right_borders[y] or right_borders[y][self].x < d[self].x then
	    right_borders[y] = d
	  end
	  if not local_right_borders[y] or local_right_borders[y][self].x < d[self].x then
	    local_right_borders[y] = d
	  end
	end
      end

      local left_borders = {}
      -- Now left for i+1 st child
      for _,d in ipairs(children[i+1][self].descendants) do
	local y = d[self].y
	if self.extended_version or not (y > child_depth and d.kind == "dummy") then
	  if not left_borders[y] or left_borders[y][self].x > d[self].x then
	    left_borders[y] = d
	  end
	end
      end

      -- Now walk down the lines and try to find out what the minimum
      -- distance needs to be.

      local shift = -math.huge
      local first_dist = left_borders[child_depth][self].x - local_right_borders[child_depth][self].x
      local is_significant = false

      for y,n2 in pairs(left_borders) do
	local n1 = right_borders[y]
	if n1 then
	  shift = math.max(shift, 
			   NodeDistances:idealSiblingDistance(self, self.graph, n1, n2) + n1[self].x - n2[self].x)
	end
	if local_right_borders[y] then
	  if y > child_depth and (left_borders[y][self].x - local_right_borders[y][self].x <= first_dist) then 
	    is_significant = true
	  end
	end
      end

      if is_significant then
	shift = shift + self.sigsep
      end

      -- Shift all nodes in the subtree by shift:
      for _,d in ipairs(children[i+1][self].descendants) do
	d[self].x = d[self].x + shift
      end
    end
    
    -- Finally, position root in the middle:
    node[self].x = (children[1][self].x + children[#children][self].x) / 2
  end
end



return ReingoldTilford1981