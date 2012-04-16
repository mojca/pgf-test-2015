-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/core/lualayer/control/pgfgd-core-loader.lua,v 1.2 2012/04/15 22:28:07 tantau Exp $



-- Imports

require "pgf"
require "pgf.gd"


-- Declare namespace
pgf.gd.control = {}


-- Preload namespace
package.loaded ["pgf.gd.control"] = pgf.gd.control

require "pgf.gd.control.TeXInterface"



-- Done

return pgf.gd.control