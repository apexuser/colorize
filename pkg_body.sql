create or replace package body colorize as

--type t_assigned_color is table of color.hex_value%type index by varchar2(4000);
--type t_string         is table of varchar2(4000) index by binary_integer;

procedure init_colors (
      p_region      in apex_plugin.t_region,
      others_color out color.hex_value%type,
      color_list   out colorize_color_table) is
begin
  if p_region.attribute_01 = '1' then
     select regexp_substr(p_region.attribute_02,'[^,]+', 1, level) 
       bulk collect into color_list
       from dual
     connect by regexp_substr(p_region.attribute_01, '[^,]+', 1, level) is not null;
     
     others_color := p_region.attribute_03;
  else
     select c.hex_value
       bulk collect into color_list
       from color c join color_set s on s.color_set_id = c.color_set_id
      where s.color_set_name = p_region.attribute_04;
     
     select s.others_color
       into others_color
       from color_set s
      where s.color_set_name = p_region.attribute_04;
  end if;
end;

procedure convert_to_result_table (
      query_result  in apex_plugin_util.t_column_value_list,
      result_table out colorize_result_table) is
begin
  for i in query_result(1).first .. query_result(1).last loop
    result_table.extend();
    result_table(result_table.last) := colorize_result_row(i, query_result(1)(i), query_result(2)(i), '', '');
  end loop;
end;

procedure assign_colors_to_first (
      result_table out colorize_result_table,
      color_list    in colorize_color_table) is
  val varchar2(4000);
begin
  select cast(multiset(select id, value, url, column_value, svg_rect_code
    from (select tt.id, tt.value, tt.url, c.column_value, tt.svg_rect_code
            from (select t.*, dense_rank() over (order by t.first_id) f_rank
                    from (select id, value, url, color, svg_rect_code, 
                                 min(id) keep (dense_rank first order by id) over (partition by value) first_id
                            from table(result_table)
                          ) t
                  ) tt join
                 (select rownum, column_value
                    from table(color_list)
                  ) c on tt.f_rank = c.column_value
          order by id
          )
    ) as colorize_result_table)
    into result_table
    from dual;
end;

procedure assign_colors_to_frequent (
      result_table out colorize_result_table,
      color_list    in colorize_color_table) is
  type t_str is table of varchar2(4000) index by binary_integer;
  type t_num is table of binary_integer index by varchar2(4000);
  count_vals t_str;
  val_counts t_num;
  cnt        number;
  val varchar2(4000);
  clr varchar2(4000);
  idx_color number;
  idx_value number;
  idx_str   varchar2(4000);
begin
  for i in query_result(1).first .. query_result(1).last loop
    if val_counts.exists(query_result(1)(i)) then
       cnt := val_counts(query_result(1)(i)) + 1;
    else
       cnt := 1;
    end if;
    val_counts(query_result(1)(i)) := cnt;
  end loop;
  
  

  idx_str := val_counts.first;
  while idx_str is not null loop
    count_vals(val_counts(idx_str)) := idx_str;
    htp.p('val_counts(' || idx_str || ') = ' || val_counts(idx_str) || ' count_vals count = ' || count_vals.count || '<br />');
    idx_str := val_counts.next(idx_str);
  end loop;
  
  idx_color := color_list.first;
  idx_value := count_vals.last;
  loop
    assigned_colors(count_vals(idx_value)) := color_list(idx_color);
    idx_color := color_list.next(idx_color);
    exit when idx_color is null;
  end loop;
htp.p('assigned_colors = ' || assigned_colors.count || '<br />');
end;

procedure prepare_defs_list (
      assigned_colors in  t_assigned_color,
      others_value    in varchar2,
      others_color    in varchar2,
      defs_list       out t_string) is
  idx varchar2(4000);
  def_template varchar2(4000) := '<style type="text/css"><![CDATA[ .#VALUE# { fill: #COLOR#; } ]]></style>';
begin
  idx := assigned_colors.first;
  while idx is not null loop
    defs_list(defs_list.count + 1) := replace(replace(def_template, '#VALUE#', idx), '#COLOR#', assigned_colors(idx));
    idx := assigned_colors.next(idx);
  end loop;
  defs_list(defs_list.count + 1) := replace(replace(def_template, '#VALUE#', others_value), '#COLOR#', others_color);
end;

procedure prepare_squares_list (
      query_result     in  apex_plugin_util.t_column_value_list,
      assigned_colors  in  t_assigned_color,
      others_color     in  varchar2,
      square_size      in  number,
      squares_in_col   in  number,
      svg_squares_list out t_string) is
  square_template varchar2(4000) := '<rect x="#X#" y="#Y#" width="#W#" height="#H#" class="#CLASS#" style="cursor:pointer;#URL#"/>';
  xpos number;
  ypos number;
  x number;
  y number;
  w number := square_size;
  h number := square_size;
  str varchar2(1000);
begin
  for i in query_result(1).first .. query_result(1).last loop
    xpos := floor(i / squares_in_col) + 1;
    ypos := i - (xpos - 1) * squares_in_col;
    x := (xpos - 1) * (square_size + 2) + 2;
    y := (ypos - 1) * (square_size + 2) + 2;
    str := replace(replace(replace(replace(square_template, '#X#', x), '#Y#', y), '#W#', w), '#H#', h);
    if assigned_colors.exists(query_result(1)(i)) then
       str := replace(str, '#CLASS#', query_result(1)(i));
    end if;
    str := replace(replace(str, '#CLASS#', query_result(1)(i)), '#URL#', query_result(2)(i));
    svg_squares_list(svg_squares_list.count + 1) := '<g><title>' || query_result(1)(i) || '</title>' || str || '</g>';
  end loop;
end;

-- before refactoring
/*
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
  result_table    colorize_result_table;
  --div_list        string_list;
  --legend_list     strstr_list;
  k               number;
  div             varchar2(1000);
  ref             varchar2(1000);
  style           varchar2(1000);
  pos             number;
  l_idx           varchar2(10);
  -- after refactoring
  others_color     color.hex_value%type;
  color_list       t_color;
  assigned_colors  t_assigned_color;
  square_size      number := nvl(p_region.attribute_06, 20);
  squares_in_col   number := nvl(p_region.attribute_07, 20);
  defs_list        t_string;
  svg_squares_list t_string;
  others_label     varchar2(4000) := nvl(p_region.attribute_08, 'Other values');
  
begin
  init_colors (p_region, others_color, color_list);
 
  query_result := apex_plugin_util.get_data (
      p_sql_statement      => p_region.source,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);
      
  if query_result(1).count = 0 then
     htp.p(p_region.no_data_found_message);
     return null;
  end if;
  
  convert_to_result_table (query_result, result_table);

  if p_region.attribute_05 = '1' then
     assign_colors_to_first (result_table, color_list, assigned_colors);
  else
     assign_colors_to_frequent (result_table, color_list, assigned_colors);
  end if;

  prepare_defs_list (assigned_colors, others_label, others_color, defs_list);
  
  prepare_squares_list (query_result, assigned_colors, others_color, square_size, squares_in_col, svg_squares_list);
  
  htp.p('<svg width="800" height="500"><defs>');
  for i in defs_list.first .. defs_list.last loop
    htp.p(defs_list(i));
  end loop;
  htp.p('</defs>');
  
  for i in svg_squares_list.first .. svg_squares_list.last loop
    htp.p(svg_squares_list(i));
  end loop;
  htp.p('</svg>');
  
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
 -- exception when others then return null;
end;

end colorize;