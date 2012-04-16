-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/control/pgf-gd-control.lua,v 1.1 2012/04/16 17:58:36 tantau Exp $



-- Imports

require "pgf"
require "pgf.gd"


-- Declare namespace
pgf.gd.lib = {}


-- Preload namespace
package.loaded ["pgf.gd.lib"] = pgf.gd.lib

require "pgf.gd.lib.Anchoring"
require "pgf.gd.lib.Components"
require "pgf.gd.lib.Events"
require "pgf.gd.lib.Orientation"
require "pgf.gd.lib.Simplifiers"
require "pgf.gd.lib.Vector"



-- Done

return pgf.gd.lib