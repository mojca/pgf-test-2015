-- Copyright 2010 by Renée Ahrens, Olof Frahm, Jens Kluttig, Matthias Schulz, Stephan Schuster
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/misc/pgfgd-algorithm-simple-demo.lua,v 1.5 2011/09/30 13:16:53 jannis-pohlmann Exp $

-- This file contains an example of how a very simple algorithm can be
-- implemented by a user.

pgf.module("pgf.graphdrawing")



--- A trivial node placing algorithm for demonstration purposes.
-- All nodes are positioned on a fixed size circle.

simple_demo = {}
simple_demo.__index = simple_demo

function simple_demo:run()
   local radius = tonumber(self.graph:getOption("/graph drawing/radius") or 28.908)
   local nodeCount = table.count_pairs(self.graph.nodes)

   local alpha = (2 * math.pi) / nodeCount
   local i = 0
   for node in table.value_iter(self.graph.nodes) do
      -- the interesting part...
      local node_radius = tonumber(node:getOption('/graph drawing/node radius')
                                   or radius)
      node.pos:set{x = node_radius * math.cos(i * alpha)}
      node.pos:set{y = node_radius * math.sin(i * alpha)}
      i = i + 1
   end
end
