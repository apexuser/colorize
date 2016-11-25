create or replace package body colorize as

type t_string is table of varchar2(4000);
reg_id number;

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

procedure reset_sequence is
  pragma autonomous_transaction;
  val number;
begin
  val := colorize_tmp_seq.nextval;
  execute immediate 'alter sequence colorize_tmp_seq increment by -' || val || ' minvalue 0';
  val := colorize_tmp_seq.nextval;
  execute immediate 'alter sequence colorize_tmp_seq increment by 1 minvalue 0';
end;

procedure convert_to_result_table (
      query_result in apex_plugin_util.t_column_value_list) is
begin
  forall i in query_result(1).first .. query_result(1).last
  insert into colorize_result (id, value, url)
  values (colorize_tmp_seq.nextval, query_result(1)(i), query_result(2)(i));

  reset_sequence;
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
    from (select distinct replace(replace(def_template, '#VALUE#', cr.value || '_' || reg_id), '#COLOR#', cr.color) svg_def
            from colorize_result cr
           where cr.color is not null
           union all
          select replace(replace(def_template, '#VALUE#', others_value || '_' || reg_id), '#COLOR#', others_color)
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
          '<rect x="'      || to_char(floor((id - 1)/squares_in_col) * (square_size + 2) + 2) ||
              '" y="'      || to_char(mod   (id - 1, squares_in_col) * (square_size + 2) + 24) ||
              '" width="'  || w ||
              '" height="' || h ||
              '" class="'  || case when color is null then others_value else value end || '_' || reg_id ||
              '" style="cursor:pointer;"/>' || case when url is null then null else '</a>' end || 
          '</g>';
end;

function legend_value (
      square_size in number,
      value       in varchar2,
      color         in varchar2) return varchar2 is
begin
  return  '<div style="display: inline-block; margin: 5px;">' ||
          '<div style=" width: ' || square_size || 'px; 
                        height: ' || square_size || 'px; 
                        background-color: ' || color || ';
                        margin: 5px; 
                        display: inline-block;
                        vertical-align: middle;"></div>' ||
          '<p style="display: inline-block; margin: 5px; vertical-align: middle;">' || value || '</p>' ||
          '</div>';
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
  reg_id := p_region.id;
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
  
  htp.p('<div style="display: inline-block; vertical-align: baseline; width: 100%; overflow-x: auto;"><svg width="' || ((ceil(query_result(1).count / squares_in_col) + 2) * square_size + 2) || 
               '" height="' || ((squares_in_col + 2) * square_size + 24) || '"><defs>');
  for i in defs_list.first .. defs_list.last loop
    htp.p(defs_list(i));
  end loop;
  htp.p('</defs>');
  
  for i in (select id, svg_rect_code from colorize_result) loop
    htp.p(i.svg_rect_code);
    if mod(i.id, squares_in_col * 5) = 0 then
       htp.p('<text x="' || to_char(floor((i.id - 1)/squares_in_col) * (square_size + 2) + 2) || '" y="20" fill="#808080">' || floor(i.id / squares_in_col) || '</text>');
    end if;
  end loop;
    
  htp.p('</svg></div>');
  
  htp.p('<div style="display: inline-block; vertical-align: baseline;">');
  for i in (select distinct value, color from colorize_result where color is not null) loop
    htp.p(legend_value(square_size, i.value, i.color));
  end loop;
  htp.p(legend_value(square_size, others_label, others_color));
  htp.p('</div>');

  delete from colorize_result;
  delete from colorize_colors;
  return null;
end;

end colorize;