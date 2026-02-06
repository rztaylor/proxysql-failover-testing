-- Set read_only mode for secondary server
-- This runs after all other init scripts (03- prefix ensures ordering)

SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;
