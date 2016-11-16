create table color (
id number,
r number(3, 0),
g number(3, 0),
b number(3, 0)
);

create sequence color_seq;

create or replace trigger bi_color
  before insert on color
  for each row
begin
  if :new.id is null then
  :new.id := color_seq.nextval;
  end if; 
end;
/

comment on table color is 'List of RGB values of choosen colors';

insert into color (r, g, b) values (128, 128, 128);
insert into color (r, g, b) values (222,   0,   0);
insert into color (r, g, b) values (  0, 222,   0);
insert into color (r, g, b) values (  0,   0, 222);
insert into color (r, g, b) values (222, 222,   0);
insert into color (r, g, b) values (222,   0, 222);
insert into color (r, g, b) values (  0, 222, 222);
insert into color (r, g, b) values (160,   0,   0);
insert into color (r, g, b) values (  0, 160,   0);
insert into color (r, g, b) values (  0,   0, 160);
insert into color (r, g, b) values (128, 128,   0);
insert into color (r, g, b) values (128,   0, 128);
insert into color (r, g, b) values (  0, 128, 128);
insert into color (r, g, b) values ( 96,   0,   0);
insert into color (r, g, b) values (  0,  96,   0);
insert into color (r, g, b) values (  0,   0,  96);
insert into color (r, g, b) values ( 96,  96,   0);
insert into color (r, g, b) values ( 96,   0,  96);
insert into color (r, g, b) values (  0,  96,  96);
insert into color (r, g, b) values (  0,   0,   0);
commit;

@pkg;
@pkg_body;
show errors