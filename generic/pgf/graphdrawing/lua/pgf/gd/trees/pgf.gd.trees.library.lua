-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/trees/pgf.gd.trees.lua,v 1.1 2012/04/19 15:22:29 tantau Exp $



---
-- \tikzname\ offers several different syntax to specify trees (see
-- Sections \ref{section-library-graphs}
-- and~\ref{section-trees}). The job of the graph drawing algorithms from
-- this library is to turn the specification of trees into beautiful
-- layouts. 
--
-- We start this section with a description of algorithms, then we have a
-- look at how missing children can be specified and at what happens when
-- the input graph is not a tree.
--
-- @library

local trees -- Library name

-- Load declarations from:
require "pgf.gd.trees.ChildSpec"
require "pgf.gd.trees.SpanningTreeComputation"

-- Load algorithms from:
require "pgf.gd.trees.ReingoldTilford1981"
