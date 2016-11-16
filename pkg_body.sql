select count(*) 
  from dxdy_message 
 where topic_id = 101728;




with mx         as (select max(id) id from color),
     user_color as (
         select t.username, userid, c.r, c.g, c.b
           from (select tt.username, userid,
                        case when mx.id <= row_number() over (order by tt.rnk) then mx.id 
                             else row_number() over (order by tt.rnk) end clr_id
                   from (select u.username, u.id userid, min(m.id) keep (dense_rank first order by m.created_on) rnk
                           from dxdy_message m join dxdy_user u on u.id = m.user_id
                          where topic_id = 101371
                          group by u.username, u.id
                         ) tt, mx
                 ) t join color c on c.id = t.clr_id)
select m.id, u.username, '#' || to_char(u.r, 'FM0x') || to_char(u.g, 'FM0x') || to_char(u.b, 'FM0x') cl
  from dxdy_message m join user_color u on m.user_id = u.userid
 where topic_id = :P4_TOPIC_ID
 order by m.id;