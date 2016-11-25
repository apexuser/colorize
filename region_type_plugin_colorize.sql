set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050000 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2013.01.01'
,p_release=>'5.0.2.00.07'
,p_default_workspace_id=>1670552497385579
,p_default_application_id=>800
,p_default_owner=>'DXDY'
);
end;
/
prompt --application/ui_types
begin
null;
end;
/
prompt --application/shared_components/plugins/region_type/colorize
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(9814802753410584)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COLORIZE'
,p_display_name=>'Colorize'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_render_function=>'colorize.render_colorize'
,p_standard_attributes=>'SOURCE_SQL:SOURCE_REQUIRED:NO_DATA_FOUND_MESSAGE'
,p_sql_min_column_count=>2
,p_sql_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'select value_column, url_column',
'  from source_table'))
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_version_identifier=>'1.0'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10149111599238980)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Take color values from'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'1'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Select a source for a color set.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(10149645394244183)
,p_plugin_attribute_id=>wwv_flow_api.id(10149111599238980)
,p_display_sequence=>10
,p_display_value=>'Manual input'
,p_return_value=>'1'
,p_help_text=>'Enter the set of colors manually.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(10150060165248574)
,p_plugin_attribute_id=>wwv_flow_api.id(10149111599238980)
,p_display_sequence=>20
,p_display_value=>'From the table'
,p_return_value=>'2'
,p_help_text=>'Color set will be taken from COLOR table.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10143823748171457)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Color set'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(10149111599238980)
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'1'
,p_help_text=>'Comma separated list of colors in the following format: #RRGGBB.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10144489695179705)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Color for "others" value'
,p_attribute_type=>'COLOR'
,p_is_required=>false
,p_default_value=>'#000000'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(10149111599238980)
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'1'
,p_help_text=>'Color for items which haven''t get color from the main set and will be named "others". The default value is black.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10157285061332713)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Color set name'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(10149111599238980)
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'2'
,p_help_text=>'The name of a color set in the color settings table.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10145633152192441)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Assign colors to:'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'1'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Defines how to assign colors to query values. If the count of different values is more than the count of colors, values without of colors get a color for others.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(10146225853195200)
,p_plugin_attribute_id=>wwv_flow_api.id(10145633152192441)
,p_display_sequence=>10
,p_display_value=>'First'
,p_return_value=>'1'
,p_help_text=>'Colors are assigned to first values.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(10146688628196642)
,p_plugin_attribute_id=>wwv_flow_api.id(10145633152192441)
,p_display_sequence=>20
,p_display_value=>'Frequent'
,p_return_value=>'2'
,p_help_text=>'Colors are assigned to the most frequent values.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10145092183185649)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Square size'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'20'
,p_is_translatable=>false
,p_help_text=>'The size of squares. Default value is 20.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10186491772338707)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Squares in a column'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'15'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_is_translatable=>false
,p_help_text=>'How many squares have to be displayed in a column. The default value is 15.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(10191081392882167)
,p_plugin_id=>wwv_flow_api.id(9814802753410584)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Label for "others" value'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'Others'
,p_is_translatable=>false
,p_help_text=>'The text will be shown in the legend as a name for "others" value.'
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false), p_is_component_import => true);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
