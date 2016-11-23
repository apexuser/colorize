create or replace package body colorize as

type t_string         is table of varchar2(4000) index by binary_integer;

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
  r number;
begin
  result_table := colorize_result_table();
  result_table.extend(query_result(1).count);
  htp.p('1 query_result = ' || query_result(1).count || ' result_table = ' || result_table.count || '<br />');
  r := result_table.first;
  for i in query_result(1).first .. query_result(1).last loop
    result_table(i) := colorize_result_row(i, query_result(1)(i), query_result(2)(i), '', '', '');
    r := result_table.next(r);
  end loop;
  htp.p('2 query_result = ' || query_result(1).count || ' result_table = ' || result_table.count || '<br />');
end;

procedure assign_colors_to_first (
      result_table in out colorize_result_table,
      color_list   in     colorize_color_table) is
begin
  select cast(multiset(
      select id, value, url, column_value, svg_rect_code
        from (select tt.id, tt.value, tt.url, c.column_value, tt.svg_def, tt.svg_rect_code
                from (select t.*, dense_rank() over (order by t.first_id) f_rank
                        from (select id, value, url, color, svg_def, svg_rect_code, 
                                     min(id) keep (dense_rank first order by id) over (partition by value) first_id
                                from table(result_table)
                              ) t
                      ) tt left join
                     (select rownum, column_value
                        from table(color_list)
                      ) c on tt.f_rank = c.rownum
              order by id
              )
    ) as colorize_result_table)
    into result_table
    from dual;
end;

procedure assign_colors_to_frequent (
      result_table in out colorize_result_table,
      color_list   in     colorize_color_table) is
      rt2 colorize_result_table;
begin
  select cast(multiset(
      select r.id, value, r.url, c.color, r.svg_def, r.svg_rect_code
        from (select id, value, url, color, svg_def, svg_rect_code, dense_rank() over (order by val_cnt desc, value) rn
                from (select id, value, url, color, svg_def, svg_rect_code, count(*) over (partition by value) val_cnt
                        from table(result_table)
                      )
              ) r left join
             (select rownum rn, column_value color
                from table(color_list)
              ) c on r.rn = c.rn
       order by id
    ) as colorize_result_table)
    into rt2
    from dual;
end;

procedure prepare_defs_list (
      result_table  in colorize_result_table,
      others_value  in varchar2,
      others_color  in varchar2,
      defs_list    out t_string) is
  idx number;
  def_template varchar2(4000) := '<style type="text/css"><![CDATA[ .#VALUE# { fill: #COLOR#; } ]]></style>';
begin
  htp.p('result_table = ' || result_table.count);
  idx := result_table.first;
  while idx is not null loop
    if result_table(idx).color is not null then
       defs_list(defs_list.count + 1) := replace(replace(def_template, '#VALUE#', result_table(idx).value), '#COLOR#', result_table(idx).color);
    end if;
    idx := result_table.next(idx);
  end loop;
  defs_list(defs_list.count + 1) := replace(replace(def_template, '#VALUE#', others_value), '#COLOR#', others_color);
end;

procedure prepare_squares_list (
      result_table   in out colorize_result_table,
      others_color   in     varchar2,
      square_size    in     number,
      squares_in_col in     number) is
  square_template varchar2(4000) := '<rect x="#X#" y="#Y#" width="#W#" height="#H#" class="#CLASS#" style="cursor:pointer;#URL#"/>';
  xpos number;
  ypos number;
  x number;
  y number;
  w number := square_size;
  h number := square_size;
  str varchar2(1000);
  i number;
begin
  i := result_table.first;
  while i is not null loop
    xpos := floor(i / squares_in_col) + 1;
    ypos := i - (xpos - 1) * squares_in_col;
    x := (xpos - 1) * (square_size + 2) + 2;
    y := (ypos - 1) * (square_size + 2) + 2;
    str := replace(replace(replace(replace(square_template, '#X#', x), '#Y#', y), '#W#', w), '#H#', h);
    str := replace(replace(str, '#CLASS#', result_table(i).value), '#URL#', result_table(i).url);
    result_table(i).svg_rect_code := str;
    i := result_table.next(i);
  end loop;
end;

function render_colorize (
      p_region              in apex_plugin.t_region,
      p_plugin              in apex_plugin.t_plugin,
      p_is_printer_friendly in boolean )
      return apex_plugin.t_region_render_result is

  query_result   apex_plugin_util.t_column_value_list;
  result_table   colorize_result_table;
  others_color   color.hex_value%type;
  color_list     colorize_color_table;
  square_size    number := nvl(p_region.attribute_06, 20);
  squares_in_col number := nvl(p_region.attribute_07, 20);
  defs_list      t_string;
  others_label   varchar2(4000) := nvl(p_region.attribute_08, 'Other values');
  i              number;
begin
  dbms_application_info.set_module('render_colorize', '');
  
  dbms_application_info.set_action('init_colors');
  
  init_colors (p_region, others_color, color_list);
  
  dbms_application_info.set_action('perform query');
  
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
  
  dbms_application_info.set_action('convert_to_result_table');
  
  convert_to_result_table (query_result, result_table);
  
  dbms_application_info.set_action('rt ' || result_table.count || ' r, color_list ' || color_list.count || ' r');
  
  htp.p('3 query_result = ' || query_result(1).count || ' result_table = ' || result_table.count || '<br />');

  if p_region.attribute_05 = '1' then
     assign_colors_to_first (result_table, color_list);
  else
     assign_colors_to_frequent (result_table, color_list);
  end if;

  prepare_defs_list (result_table, others_label, others_color, defs_list);
  
  prepare_squares_list (result_table, others_color, square_size, squares_in_col);
  
  htp.p('<svg width="800" height="500"><defs>');
  for i in defs_list.first .. defs_list.last loop
    htp.p(defs_list(i));
  end loop;
  htp.p('</defs>');
  
  i := result_table.first;
  while i is not null loop
    htp.p(result_table(i).svg_rect_code);
  end loop;
  htp.p('</svg>');
  
  dbms_application_info.set_module('', '');
  
  return null;
 -- exception when others then return null;
end;

end colorize;