create or replace package body colorize as

type t_string is table of varchar2(4000);

procedure init_colors (
      p_region      in apex_plugin.t_region,
      others_color out color.hex_value%type) is
begin
  if p_region.attribute_01 = '1' then
     insert into colorize_colors (id, color)
     select rownum, regexp_substr(p_region.attribute_02,'[^,]+', 1, level) 
       from dual
    connect by regexp_substr(p_region.attribute_02, '[^,]+', 1, level) is not null;

     others_color := p_region.attribute_03;
  else
     insert into colorize_colors (id, color)
     select rownum, c.hex_value
       from color c join color_set s on s.color_set_id = c.color_set_id
      where s.color_set_name = p_region.attribute_04;
     
     select s.others_color
       into others_color
       from color_set s
      where s.color_set_name = p_region.attribute_04;
  end if;
end;

procedure convert_to_result_table (
      query_result in apex_plugin_util.t_column_value_list) is
begin
  forall i in query_result(1).first .. query_result(1).last
  insert into colorize_result (id, value, url)
  values (query_result(1)(i), query_result(2)(i), query_result(3)(i));
end;

procedure assign_colors (p_region in apex_plugin.t_region) is
begin
  if p_region.attribute_05 = '1' then
     merge into colorize_result cr
     using (select tt.id, tt.value, cc.color
                from (select t.*, dense_rank() over (order by t.first_id) f_rank
                        from (select id, value, min(id) keep (dense_rank first order by id) over (partition by value) first_id
                                from colorize_result
                              ) t
                      ) tt left join colorize_colors cc on tt.f_rank = cc.id) cl on (cr.id = cl.id)
      when matched then update
       set cr.color = cl.color;
  else
     merge into colorize_result cr
     using (select r.id, r.value, cc.color
              from (select id, value, dense_rank() over (order by val_cnt desc, value) rn
                      from (select id, value, count(*) over (partition by value) val_cnt
                              from colorize_result
                            )
                    ) r left join colorize_colors cc on r.rn = cc.id) cl on (cr.id = cl.id)
      when matched then update
       set cr.color = cl.color;
  end if;
end;

procedure prepare_defs_list (
      others_value  in varchar2,
      others_color  in varchar2,
      defs_list    out t_string) is
  idx number;
  def_template varchar2(4000) := '<style type="text/css"><![CDATA[ .#VALUE# { fill: #COLOR#; } ]]></style>';
begin
  select svg_def
    bulk collect into defs_list
    from (select replace(replace(def_template, '#VALUE#', cr.value), '#COLOR#', cr.color) svg_def
            from colorize_result cr
           union all
          select replace(replace(def_template, '#VALUE#', others_value), '#COLOR#', others_color)
            from dual
          );
end;

procedure prepare_squares (
      others_value   in varchar2,
      others_color   in varchar2,
      square_size    in number,
      squares_in_col in number) is
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
  update colorize_result
     set svg_rect_code = 
          '<g><title>'     || value || '</title>' || case when url is null then null else '<a xlink:href="' || url || '" target="_blank">' end ||
          '<rect x="'      || to_char(floor(id / squares_in_col) * (square_size + 2) + 2) ||
              '" y="'      || to_char((id - floor(id / squares_in_col) * squares_in_col - 1) * (square_size + 2) + 2) ||
              '" width="'  || w ||
              '" height="' || h ||
              '" class="'  || case when color is null then others_value else value end ||
              '" style="cursor:pointer;"/>' || case when url is null then null else '</a>' end || 
          '</g>';
end;

function render_colorize (
      p_region              in apex_plugin.t_region,
      p_plugin              in apex_plugin.t_plugin,
      p_is_printer_friendly in boolean )
      return apex_plugin.t_region_render_result is

  query_result   apex_plugin_util.t_column_value_list;
  others_color   color.hex_value%type;
  square_size    number := nvl(p_region.attribute_06, 20);
  squares_in_col number := nvl(p_region.attribute_07, 20);
  defs_list      t_string;
  others_label   varchar2(4000) := nvl(p_region.attribute_08, 'Other values');
  i              number;
begin
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
  
  init_colors (p_region, others_color);
  convert_to_result_table (query_result);
  assign_colors(p_region);
  prepare_defs_list (others_label, others_color, defs_list);
  prepare_squares (others_label, others_color, square_size, squares_in_col);
  
  htp.p('<div><svg width="' || ((ceil(query_result(1).count / squares_in_col) + 2) * square_size + 2) || 
               '" height="' || ((squares_in_col + 2) * square_size + 2) || '"><defs>');
  for i in defs_list.first .. defs_list.last loop
    htp.p(defs_list(i));
  end loop;
  htp.p('</defs>');
  
  for i in (select svg_rect_code from colorize_result) loop
    htp.p(i.svg_rect_code);
  end loop;
  
  htp.p('</svg></div>');
  
  htp.p('<div>');
  for i in defs_list.first .. defs_list.last loop
    htp.p('<div></div>');
  end loop;
  htp.p('</div>');
  
  return null;
  --exception when others then return null;
end;

end colorize;