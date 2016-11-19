create or replace package body colorize as

type result_set is record (
  value       varchar2(4000),
  url         varchar2(4000)/*,
  color_value color.hex_value%type*/);

type t_result         is table of result_set;-- index by color.hex_value%type;
type t_color          is table of color.hex_value%type;-- index by varchar2(4000);
type t_assigned_color is table of color.hex_value%type index by varchar2(4000);

procedure init_colors (
      p_region      in  apex_plugin.t_region,
      default_color out color.hex_value%type,
      color_list    out t_color) is
begin
  if p_region.attribute_01 = '1' then
     select regexp_substr(p_region.attribute_02,'[^,]+', 1, level) 
       bulk collect into color_list
       from dual
     connect by regexp_substr(p_region.attribute_01, '[^,]+', 1, level) is not null;
     
     default_color := p_region.attribute_03;
  else
     select c.hex_value
       bulk collect into color_list
       from color c join color_set s on s.color_set_id = c.color_set_id
      where s.color_set_name = p_region.attribute_04;
     
     select s.default_color
       into default_color
       from color_set s
      where s.color_set_name = p_region.attribute_04;
  end if;
end;

procedure assign_colors_to_first (
      query_result    in  apex_plugin_util.t_column_value_list,
      color_list      in  t_color,
      assigned_colors out t_assigned_color) is
  val varchar2(4000);
begin
  for i in query_result(1).first .. query_result(1).last loop
    assigned_colors(query_result(1)(i)) := ' ';
    exit when assigned_colors.count = color_list.count;
  end loop;
  
  val := assigned_colors.first;
  for i in color_list.first .. color_list.last loop
    assigned_colors(val) := color_list(i);
    val := assigned_colors.next(val);
  end loop;
end;

procedure assign_colors_to_frequent (
      query_result    in  apex_plugin_util.t_column_value_list,
      color_list      in  t_color,
      assigned_colors out t_assigned_color) is
  type t_str is table of varchar2(4000) index by binary_integer;
  type t_num is table of binary_integer index by varchar2(4000);
  count_vals t_str;
  val_counts t_num;
  cnt        number;
  val varchar2(4000);
  clr varchar2(4000);
  idx_color number;
  idx_value number;
begin
  for i in query_result(1).first .. query_result(1).last loop
    if val_counts.exists(query_result(1)(i)) then
       cnt := val_counts(query_result(1)(i)) + 1;
    else
       cnt := 1;
    end if;
    val_counts(query_result(1)(i)) := cnt;
  end loop;

  for i in val_counts.first .. val_counts.last loop
    count_vals(val_counts(i)) := i;
  end loop;
  
  idx_color := color_list.first;
  idx_value := count_vals.last;
  loop
    assigned_colors(count_vals(idx_value)) := color_list(idx_color);
    idx_color := color_list.next(idx_color);
    exit when idx_color is null;
  end loop;
end;


-- before refactoring
/*inner_style varchar2(500) :=
    'display: inline-block; vertical-align: middle; margin: 1px; width: 20px; height: 20px; cursor:pointer;';
inner_div varchar2(500) :=
    '<div onclick="location.href=''#REF#'';" style="#STYLE#" title="#TITLE#"></div>';
css_color_attr varchar2(30) := ' background-color: ';
type string_list is table of varchar2(4000) index by binary_integer;
type strstr_list is table of varchar2(4000) index by varchar2(10);

*/

function render_colorize (
      p_region              in apex_plugin.t_region,
      p_plugin              in apex_plugin.t_plugin,
      p_is_printer_friendly in boolean )
      return apex_plugin.t_region_render_result is

  query_result    apex_plugin_util.t_column_value_list;
  --div_list        string_list;
  --legend_list     strstr_list;
  k               number;
  div             varchar2(1000);
  ref             varchar2(1000);
  style           varchar2(1000);
  pos             number;
  l_idx           varchar2(10);
  -- after refactoring
  default_color   color.hex_value%type;
  color_list      t_color;
  assigned_colors t_assigned_color;
begin
  init_colors (p_region, default_color, color_list);

  query_result := apex_plugin_util.get_data (
      p_sql_statement      => p_region.source,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);

  if p_region.attribute_05 = '1' then
     assign_colors_to_first (query_result, color_list, assigned_colors);
  else
     assign_colors_to_frequent (query_result, color_list, assigned_colors);
  end if;

--before refactoring:
/*
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
*/
  return null;
end;

end colorize;