create sequence color_seq;

create table color_set (
  color_set_id   number,
  color_set_name varchar2(100),
  others_color   varchar2(7) default '#000000'
);

create or replace trigger bi_color_set
  before insert on color_set
  for each row
begin
  if :new.color_set_id is null then
  :new.color_set_id := color_seq.nextval;
  end if; 
end;
/

alter table color_set add constraint color_set_fk primary key (color_set_id);
alter table color_set add constraint color_set_name_uq unique (color_set_name);

comment on table  color_set is                'Stores sets of colors for colorize plug-in';
comment on column color_set.color_set_id is   'primary key';
comment on column color_set.color_set_name is 'color set identifier';
comment on column color_set.others_color is   'color for other items';

insert into color_set (color_set_name) values ('default set');

  --#### color table
create table color (
  color_id     number,
  hex_value    varchar(7),
  color_set_id number
);

create or replace trigger bi_color
  before insert on color
  for each row
begin
  if :new.color_id is null then
  :new.color_id := color_seq.nextval;
  end if; 
end;
/

alter table color add constraint color_fk primary key (color_id);
alter table color add constraint color_color_set_fk foreign key (color_set_id) references color_set (color_set_id);

comment on table  color is              'List of RGB values of choosen colors';
comment on column color.color_id is     'primary key';
comment on column color.hex_value is    'hex value of a RGB color in format #rrggbb';
comment on column color.color_set_id is 'reference to color set';

insert into color (hex_value, color_set_id) values ('#808080', 1);
insert into color (hex_value, color_set_id) values ('#dedede', 1);
insert into color (hex_value, color_set_id) values ('#00de00', 1);
insert into color (hex_value, color_set_id) values ('#0000de', 1);
insert into color (hex_value, color_set_id) values ('#dede00', 1);
insert into color (hex_value, color_set_id) values ('#de00de', 1);
insert into color (hex_value, color_set_id) values ('#00dede', 1);
insert into color (hex_value, color_set_id) values ('#a00000', 1);
insert into color (hex_value, color_set_id) values ('#00a000', 1);
insert into color (hex_value, color_set_id) values ('#0000a0', 1);
insert into color (hex_value, color_set_id) values ('#808000', 1);
insert into color (hex_value, color_set_id) values ('#800080', 1);
insert into color (hex_value, color_set_id) values ('#008080', 1);
insert into color (hex_value, color_set_id) values ('#600000', 1);
insert into color (hex_value, color_set_id) values ('#006000', 1);
insert into color (hex_value, color_set_id) values ('#000060', 1);
insert into color (hex_value, color_set_id) values ('#606000', 1);
insert into color (hex_value, color_set_id) values ('#600060', 1);
insert into color (hex_value, color_set_id) values ('#006060', 1);
insert into color (hex_value, color_set_id) values ('#000000', 1);
commit;

create global temporary table colorize_result (
  id            number,
  value         varchar2(4000),
  url           varchar2(4000),
  color         varchar2(7),
  svg_rect_code varchar2(4000)
) on commit delete rows;

create global temporary table colorize_colors (
  id            number,
  color         varchar2(7)
) on commit delete rows;

@pkg;
@pkg_body;
show errors