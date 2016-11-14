create or replace package colorize as
  function render_colorize (
        p_region              in apex_plugin.t_region,
        p_plugin              in apex_plugin.t_plugin,
        p_is_printer_friendly in boolean )
        return apex_plugin.t_region_render_result;

end colorize;
/
