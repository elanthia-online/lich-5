# WP5 (G04 G23 G24 G52 G80 G79): the room components and the room subtitle, from REAL
# DragonRealms rows (from a tester's live capture; the player name replaced) plus synthetic edge rows.
# Game.cs:1485-1521, 1757-1831, 2656-2718 R.
waitfor STEP1
echo rn=[$roomname] uid=[$uid]
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist]
echo pl=[$roomplayers] ex=[$roomexits]
echo n=[$north] se=[$southeast] s=[$south]
echo desc=[$roomdesc]
echo sup=[$inside] [$gameroomid] [$name] [$level] [$maxhealth] [$roomtitle] [$Mana] [$Bleeding] [$RoomObjs] v=[$version]
waitfor STEP2
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist]
echo pl=[$roomplayers]
waitfor STEP3
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist]
echo pl=[$roomplayers]
waitfor STEP4
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist] pl=[$roomplayers] ex=[$roomexits]
echo desc=[$roomdesc]
waitfor STEP5
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist]
waitfor STEP6
echo objs=[$roomobjs] mc=[$monstercount] ml=[$monsterlist]
echo rn=[$roomname] uid=[$uid]
waitfor STEP7
echo rn=[$roomname] uid=[$uid] objs=[$roomobjs] mc=[$monstercount]
