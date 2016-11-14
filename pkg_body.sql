create or replace package body colorize as

inner_style varchar2(500) :=
    'display: inline-block; vertical-align: middle; margin: 1px; width: 20px; height: 20px; cursor:pointer;';
inner_div varchar2(500) :=
    '<div onclick="location.href=''#REF#'';" style="#STYLE#" title="#TITLE#"></div>';
css_color_attr varchar2(30) := ' background-color: ';
type string_list is table of varchar2(4000) index by binary_integer;
type strstr_list is table of varchar2(4000) index by varchar2(10);

function render_colorize (
      p_region              in apex_plugin.t_region,
      p_plugin              in apex_plugin.t_plugin,
      p_is_printer_friendly in boolean )
      return apex_plugin.t_region_render_result is

  query_result    apex_plugin_util.t_column_value_list;
  div_list        string_list;
  legend_list     strstr_list;
  k               number;
  div             varchar2(1000);
  ref             varchar2(1000);
  style           varchar2(1000);
  pos             number;
  l_idx           varchar2(10);
begin
  query_result := apex_plugin_util.get_data (
      p_sql_statement      => p_region.source,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);

  k := query_result.first;
  for i in query_result(k).first .. query_result(k).last loop
    ref := 'http://dxdy.ru/post' || query_result(1)(i) || '.html#p' || query_result(1)(i);
    style := inner_style || css_color_attr || query_result(3)(i);

    div := replace(inner_div, '#TITLE#', query_result(2)(i));
    div := replace(      div,   '#REF#', ref);
    div := replace(      div, '#STYLE#', style);

    div_list(div_list.count + 1) := div;

    legend_list(query_result(3)(i)) := query_result(2)(i);
  end loop;

  k := ceil(div_list.count / 15);
  htp.p('<div style="float: left; clear: both;">');
  for i in 1 .. 15 loop
    htp.p('<div style="float: left; clear: both; display: inline-block; overflow-x: auto; overflow-y: hidden; white-space: nowrap; margin: 1px;">');
    for j in 1 .. k loop
      pos := (j - 1) * 15 + i;

      if pos <= div_list.last then
         htp.p(div_list(pos));
      end if;
    end loop;
    htp.p('</div>');
  end loop;
  htp.p('</div>');

  htp.p('<div style="float: left; clear: both; margin: 20px;">');
  l_idx := legend_list.first;
  while (l_idx is not null) loop
    htp.p('<div style="display: inline-block; vertical-align: middle; margin: 2px; width: 150px; height: 30px;">');
    htp.p('<div style="display: inline-block; vertical-align: middle; margin: 1px; width:  20px; height: 20px; ' || css_color_attr || l_idx || '"></div>');
    htp.p('<div style="display: inline-block; vertical-align: middle; margin: 1px; height: 20px;">' || legend_list(l_idx) || '</div>');
    htp.p('</div>');
    l_idx := legend_list.next(l_idx);
  end loop;
  htp.p('</div>');

  return null;
end;

end colorize;
/