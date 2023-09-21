#請搜尋[每次填報更改]來更改內容

rm(list=ls())

# 載入所需套件
#隱藏警告訊息
suppressWarnings({
  suppressPackageStartupMessages({
  library(DBI)
  library(odbc)
  library(magrittr)
  library(dplyr)
  library(readxl)
  library(stringr)
  library(openxlsx)
  library(tidyr)
  library(reshape2)
  })
})

time_now <- Sys.time()

#[每次填報更改]請輸入本次填報設定檔標題(字串需與標題完全相符，否則會找不到)
title <- "112學年度上學期高級中等學校教育人力資源資料庫（全國學校人事）"

#[每次填報更改]請更改自己管區的學校代碼
dis <- c(
  "030305", 
  "030403", 
  "033302", 
  "033304", 
  "033306", 
  "033316", 
  "033325", 
  "033327", 
  "033407", 
  "033408", 
  "034306", 
  "034312", 
  "034314", 
  "034319", 
  "034332", 
  "034335", 
  "034347", 
  "034348", 
  "034399", 
  "070301", 
  "070304", 
  "070307", 
  "070316", 
  "070319", 
  "070401", 
  "070402", 
  "070403", 
  "070405", 
  "070406", 
  "070408", 
  "070409", 
  "070410", 
  "070415", 
  "074308", 
  "074313", 
  "074323", 
  "074328", 
  "074339", 
  "080302", 
  "080305", 
  "080307", 
  "080308", 
  "080401", 
  "080403", 
  "080404", 
  "080406", 
  "080410", 
  "084309", 
  "101303", 
  "101304", 
  "101406", 
  "121302", 
  "121306", 
  "121307", 
  "121318", 
  "121320", 
  "121405", 
  "121410", 
  "121413", 
  "121415", 
  "121417", 
  "140301", 
  "140302", 
  "140303", 
  "140404", 
  "140405", 
  "140408", 
  "141301", 
  "141307", 
  "141406", 
  "144322", 
  "170301", 
  "170302", 
  "170403", 
  "170404", 
  "173304", 
  "173306", 
  "173307", 
  "173314", 
  "181305", 
  "181306", 
  "181307", 
  "181308", 
  "201304", 
  "201309", 
  "201310", 
  "201312", 
  "201313", 
  "201314", 
  "201408", 
  "311401", 
  "313301", 
  "313302", 
  "321399", 
  "323301", 
  "323302", 
  "323401", 
  "323402", 
  "330301", 
  "331301", 
  "331302", 
  "331304", 
  "331402", 
  "331403", 
  "331404", 
  "333301", 
  "333304", 
  "333401", 
  "341302", 
  "341402", 
  "343301", 
  "343302", 
  "343303", 
  "351301", 
  "351402", 
  "353301", 
  "353302", 
  "353303", 
  "361301", 
  "361401", 
  "363301", 
  "363302", 
  "373301", 
  "373302", 
  "380301", 
  "381301", 
  "381302", 
  "381303", 
  "381304", 
  "381305", 
  "381306", 
  "383301", 
  "383302", 
  "383303", 
  "383401", 
  "393301", 
  "393302", 
  "393401", 
  "401301", 
  "401302", 
  "401303", 
  "403301", 
  "403302", 
  "403303", 
  "403401", 
  "411301", 
  "411302", 
  "411303", 
  "411401", 
  "413301", 
  "413302", 
  "413401", 
  "421301", 
  "421302", 
  "421303", 
  "421404", 
  "423301", 
  "423302", 
  "521301", 
  "521303", 
  "521401", 
  "551301", 
  "551303", 
  "551402", 
  "581301", 
  "581302", 
  "581401", 
  "581402", 
  "720301", 
  "351B09", 
  "361B09"
)

checkfile_server <- "\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\檢核語法檔\\R\\自動化資料檢核結果\\edhr-112t1-check_print-人事(測試).xlsx" #[每次填報更改]請更改本次server匯出的檢核結果檔之路徑
check02_server <- readxl :: read_excel(checkfile_server)

#審核同意的名單 = check02_server subset自己管區學校的名單
list_agree <- check02_server %>% 
  select("organization_id") %>% 
  subset(organization_id %in% dis) %>% 
  mutate(agree = 1)

#載入server端產出的檢核結果excel檔
check02 <- check02_server %>%
  subset(organization_id %in% dis)

#[每次填報更改]以下個案處理請依自己實際需求修改
# 計畫端個案處理 -------------------------------------------------------------------

# #私立協同高中(101304)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：99人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：99；差異百分比0.0%" & check02$organization_id == "101304", "", check02$flag95)
# 
# #私立萬能工商(101406)
#   #實習處電算中心的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "101406", "", check02$flag62)
#   #吳佳諭 李永彰 謝鈺鴻 在上學年填報後到職
# check02$flag93 <- if_else(check02$flag93 == "離退教職員(工)資料表：吳佳諭 李永彰 謝鈺鴻（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年8月1日-112年1月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）" & check02$organization_id == "101406", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：49人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：47；差異百分比-4.3%" & check02$organization_id == "101406", "", check02$flag95)
# 
# #私立光禾華德福實驗學校(121302)
#   #確實沒有圖書館主管，有教務處主管 學務處主管 總務處主管 輔導室主管 人事室主管 主（會）計室主管，但各處室分別僅一人管理，職稱不是主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：教務處主管 學務處主管 總務處主管 輔導室主管 圖書館主管 人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121302", "", check02$flag1)
#   #陳淑市 皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 == "姓名：陳淑市（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第一學期（111年8月1日-112年1月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）" & check02$organization_id == "121302", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：7人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：12；差異百分比41.7%" & check02$organization_id == "121302", "", check02$flag95)
# 
# #財團法人新光高中(121306)
#   #確實沒有學務處主管 總務處主管 圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：學務處主管 總務處主管 圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121306", "", check02$flag1)
# 
# #財團法人普門中學(121307)
#   #確實沒有實習處主管 人事室主管(不為該校教職員 且不支薪)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：實習處主管 人事室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121307", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "121307", "", check02$flag18)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "121307", "", check02$flag80)
#   #邱淑貞 陳昀筠 皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 == "姓名：邱淑貞 陳昀筠（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第一學期（111年8月1日-112年1月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）" & check02$organization_id == "121307", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：46人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：45；差異百分比-2.2%" & check02$organization_id == "121307", "", check02$flag95)
# 
# #私立正義高中(121318)
#   #確實沒有圖書館主管，實際上於教務處會有人去管理圖書館
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121318", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "121318", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：23人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：25；差異百分比8.0%" & check02$organization_id == "121318", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：呂時傑（約聘僱 學務處主任） 蔡永融（約聘僱 總務處主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "121318", "", check02$flag96)
# 
# #私立義大國際高中(121320)
#   #確實沒有設置圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121320", "", check02$flag1)
#   #學務處設有主任 副主任
# check02$flag18 <- if_else(check02$flag18 == "學務處主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "121320", "", check02$flag18)
#   #人事室、校長室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "121320", "", check02$flag62)
#   #William Joseph Tolley 110-2教員資料表之護照號碼填錯，本次會更正護照號碼
# check02$flag86 <- if_else(check02$flag86 == "姓名：William Joseph Tolley（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第一學期（111年8月1日-112年1月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）" & check02$organization_id == "121320", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：33人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：39；差異百分比15.4%" & check02$organization_id == "121320", "", check02$flag95)
#   #柯瓊琪（碩士學位畢業學校（一）：VNIVERSITAS PENNSYLVANIENSIS）正確
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：柯瓊琪（碩士學位畢業學校（一）：VNIVERSITASPENNSYLVANIENSIS）" & check02$organization_id == "121320", "", check02$spe6)
# 
# #私立中山工商(121405)
#   #何曉富 吳俊德 唐美琪 姚譯婷 張瑟蘭 曾瑋 朱雅琳 李姈燕 李尚哲 林子軒 林文平 毛鳳敏 江瑜恒 涂玉嬿 王祺鑠 王麗玲 簡正佳 葉玲曲 蒲典聖 蔡寶月 蔡幸美 蘇漢章 許華欽 謝昀達 謝智鈞 郭媛婷 鍾曉慧 陳俐妤 陳家(方方土) 陳理君 陳美月 陳菁徽 陳薇 黃宏仁 黃海山 黃熙達 黃琡雯 黃靖雯 黃顯貴   非上學期離退
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "121405", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：316人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：313；差異百分比-1.0%" & check02$organization_id == "121405", "", check02$flag95)
# 
# #財團法人新光高中(121306)
#   #確實沒有設置學務處主管 總務處主管 圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：學務處主管 總務處主管 圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121306", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "121306", "", check02$flag2)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：12人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：7；差異百分比-71.4%" & check02$organization_id == "121306", "", check02$flag95)
# 
# #私立旗美商工(121410)
#   #確實沒有設置學務處主管 輔導室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：學務處主管 輔導室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121410", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "121410", "", check02$flag2)
#   #放過學校 職員(工)資料表專任人員人數偏低、教員資料表專任教學人員人數偏低、教員資料表主聘單位各類別人數分布異常、一年以上與任教領域相關之業界實務工作經驗人數偏多。
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。；教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。教員資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。一年以上與任教領域相關之業界實務工作經驗人數偏多（請再協助確認，『是否具備一年以上與任教領域相關之業界實務工作經驗』填寫『Y』之教員，是否確依欄位說明具備此經驗）" & check02$organization_id == "121410", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：3人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：3；差異百分比0.0%" & check02$organization_id == "121410", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：尹素月（約聘僱 會計室會計主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "121410", "", check02$flag96)
#   #林春貴 國立屏東大學	教育行政
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：林春貴（博士學位畢業系所（一）：教育行政）" & check02$organization_id == "121410", "", check02$spe6)
# 
# #私立高英工商(121413)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：61人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：51；差異百分比-19.6%" & check02$organization_id == "121413", "", check02$flag95)
# 
# #私立華德工家(121415)
#   #圖書館主任編制在教務處下
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121415", "", check02$flag1)
#   #教務處教務主任 教務處圖書室主任
# check02$flag18 <- if_else(check02$flag18 == "教務處主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "121415", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：22人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：20；差異百分比-10.0%" & check02$organization_id == "121415", "", check02$flag95)
# 
# #私立高苑工商(121417)
#   #確實沒有圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "121417", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag3 <- if_else(check02$flag3 == "請學校確認是否設置學程主任" & check02$organization_id == "121417", "", check02$flag3)
#   #放過學校 教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。一年以上與任教領域相關之業界實務工作經驗人數偏多。
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。一年以上與任教領域相關之業界實務工作經驗人數偏多（請再協助確認，『是否具備一年以上與任教領域相關之業界實務工作經驗』填寫『Y』之教員，是否確依欄位說明具備此經驗）" & check02$organization_id == "121417", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：53人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：52；差異百分比-1.9%" & check02$organization_id == "121417", "", check02$flag95)
# 
# #臺東縣均一高中(141301)
#   #確實沒有設置圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "141301", "", check02$flag1)
#   #放過學校 教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "141301", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：25人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：30；差異百分比16.7%" & check02$organization_id == "141301", "", check02$flag95)
# 
# #私立育仁高中(141307)
#   #確實沒有設置輔導室主管 圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "141307", "", check02$flag1)
#   #沒有設置科主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "141307", "", check02$flag2)
#   #放過學校 教員資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "141307", "", check02$flag18)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "141307", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：13人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：14；差異百分比7.1%" & check02$organization_id == "141307", "", check02$flag95)
# 
# #私立公東高工(141406)
#   #確實沒有設置圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "141406", "", check02$flag1)
#   #輔導室主任、實習輔導處主任
# check02$flag18 <- if_else(check02$flag18 == "輔導室主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "141406", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：39人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：38；差異百分比-2.6%" & check02$organization_id == "141406", "", check02$flag95)
# 
# #私立光復高中(181305)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "181305", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：179人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：178；差異百分比-0.6%" & check02$organization_id == "181305", "", check02$flag95)
#   #謝馥霞（碩士學位畢業學校（一）：NEW ENGLAND CONSERVATORY OF MUSIC）正確
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：謝馥霞（碩士學位畢業學校（一）：NEWENGLANDCONSERVATORYOFMUSIC）" & check02$organization_id == "181305", "", check02$spe6)
# 
# #私立曙光女中(181306)
#   #確實沒有設置實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "181306", "", check02$flag1)
#   #沒有設置科主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "181306", "", check02$flag2)
#   #沒有設置學程主任
# check02$flag3 <- if_else(check02$flag3 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "181306", "", check02$flag3)
#   #高中部教務主任、國中部教務主任
# check02$flag18 <- if_else(check02$flag18 == "教務處主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "181306", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：98人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：99；差異百分比1.0%" & check02$organization_id == "181306", "", check02$flag95)
#   #楊昆峰，碩士40學分班，確實取得學位；魯和鳳，國立政治大學 教育學院學校行政
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：楊昆峰（碩士學位畢業系所（一）：教師在職進修碩士40學分班） 魯和鳳（碩士學位畢業系所（一）：教育學院學校行政）" & check02$organization_id == "181306", "", check02$spe6)
# 
# #私立磐石高中(181307)
#   #確實沒有設置圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "181307", "", check02$flag1)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：102人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：103；差異百分比1.0%" & check02$organization_id == "181307", "", check02$flag95)
# 
# #私立世界高中(181308)
#   #確實沒有實習處主管(有實習處(實輔處)) 圖書館主任(教務處有人會管理，實際上沒有相關職稱)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "181308", "", check02$flag1)
#   #放過學校 教員資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "181308", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：19人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：17；差異百分比-11.8%" & check02$organization_id == "181308", "", check02$flag95)
#   #洪子珊（碩士學位畢業學校（一）：北愛荷華） 正確
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：洪子珊（碩士學位畢業學校（一）：北愛荷華）" & check02$organization_id == "181308", "", check02$spe6)
# 
# #私立興華高中(201304)
#   #確實沒有設置主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201304", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "201304", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：46人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：45；差異百分比-2.2%" & check02$organization_id == "201304", "", check02$flag95)
# 
# #私立仁義高中(201309)
#   #確實沒有設置人事室主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201309", "", check02$flag1)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：0人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：2；差異百分比100.0%" & check02$organization_id == "201309", "", check02$flag95)
# 
# #私立嘉華高中(201310)
#   #確實沒有圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201310", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低、教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。；教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "201310", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：40人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：37；差異百分比-8.1%" & check02$organization_id == "201310", "", check02$flag95)
# 
# #私立輔仁高中(201312)
#   #確實沒有圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201312", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "201312", "", check02$flag2)
#   #放過學校 職員(工)資料表專任人員人數偏低、教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "201312", "", check02$flag18)
#   #圖書館的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "201312", "", check02$flag62)
#   #陳志偉 非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "201312", "", check02$flag86)
#   #劉振廷 施宣竹 在上學年填報後到職
# check02$flag93 <- if_else(check02$flag93 == "離退教職員(工)資料表：劉振廷 施宣竹（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年8月1日-112年1月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）" & check02$organization_id == "201312", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：65人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：63；差異百分比-3.2%" & check02$organization_id == "201312", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：陳旺（約聘僱 校長室主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "201312", "", check02$flag96)
# 
# #私立宏仁女中(201313)
#   #確實沒有輔導室主管 圖書館主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201313", "", check02$flag1)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：18人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：24；差異百分比25.0%" & check02$organization_id == "201313", "", check02$flag95)
# 
# #私立立仁高中(201314)
#   #確實沒有設置圖書館主管 人事室主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201314", "", check02$flag1)
#   #鐘點教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "201314", "", check02$flag80)
#   #彭月琳 林???茹 郭巧雲 黃子信皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "201314", "", check02$flag86)
#   #吳欣潔 在上學年填報後到職且在111/8/1前離職
# check02$flag93 <- if_else(check02$flag93 == "離退教職員(工)資料表：吳欣潔（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年8月1日-112年1月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）" & check02$organization_id == "201314", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：10人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：10；差異百分比0.0%" & check02$organization_id == "201314", "", check02$flag95)
# 
# #私立東吳工家(201408)
#   #確實沒有圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "201408", "", check02$flag1)
#   #職稱及服務單位無誤 實習處即測即評及發證中心確實有兩位組長
#     # 吳文賓（兼任行政職服務單位(二)：技藝學程中心(台南區)） 
#     # 張博良（兼任行政職服務單位(二)：技藝學程中心(嘉義縣)） 
#     # 陳明堂（兼任行政職服務單位(一)：實習處即測即評及發證中心 兼任行政職職稱(一)：組長；兼任行政職服務單位(二)：技藝學程中心(嘉義市) 兼任行政職職稱(二)：組長） 
#     # 張瓊惠（兼任行政職服務單位(一)：技藝學程中心 兼任行政職職稱(一)：組長） 
#     # 林正凰（兼任行政職服務單位(一)：圖書室 兼任行政職職稱(一)：組長） 
#     # 翁韻茹（兼任行政職服務單位(一)：實習處即測即評及發證中心 兼任行政職職稱(一)：組長） 
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "201408", "", check02$flag62)
#   #陳明堂 110-2教員資料表之身分證填錯，本次會更正身分證
# check02$flag86 <- if_else(check02$flag86 == "姓名：陳明堂（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第一學期（111年8月1日-112年1月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）" & check02$organization_id == "201408", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：94人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：99；差異百分比5.1%" & check02$organization_id == "201408", "", check02$flag95)
# 
# #臺北市育達高中(311401)
#   #確實沒有輔導室主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "311401", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低、教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "311401", "", check02$flag18)
#   #葉千綺約15歲開始工作無誤
# check02$flag39 <- if_else(check02$flag39 == "請確認該員之「本校到職日期」、「本校任職需扣除之年資」、「本校到職前學校服務總年資」，職員(工)資料表：葉千綺58歲，但學校工作總年資有43年（約15歲開始工作）" & check02$organization_id == "311401", "", check02$flag39)
#   #張芸榛 鄭琇璘皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 == "姓名：張芸榛 鄭琇璘（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第一學期（111年8月1日-112年1月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）" & check02$organization_id == "311401", "", check02$flag86)
#   #僅姓名多一個全型空格
# check02$flag91 <- if_else(check02$flag91 == "請確認：林　永/林永（離退人員於上一期資料填報姓名不相同。如已更名，請來電告知）" & check02$organization_id == "311401", "", check02$flag91)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：81人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：85；差異百分比4.7%" & check02$organization_id == "311401", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：劉邦豪（約聘僱 智能監控中心智能監控中心主任） 梁淑惠（約聘僱 會計室約聘會計主任） 楊庭卉（約聘僱 綜合企劃中心綜合企劃中心主任） 洪毓俊（約聘僱 公關事務中心約聘校務主任兼公關事務主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "311401", "", check02$flag96)
# 
# #臺北市私立協和祐德高級中學(321399)
#   #確實沒有設置圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "321399", "", check02$flag1)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "321399", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：23人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：23；差異百分比0.0%" & check02$organization_id == "321399", "", check02$flag95)
# 
# #私立延平中學(331301)
#   #侯淑敏 吳志雄 非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "331301", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：133人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：131；差異百分比-1.5%" & check02$organization_id == "331301", "", check02$flag95)
# 
# #私立金甌女中(331302)
#   #確實沒有設置圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "331302", "", check02$flag1)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "331302", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：61人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：61；差異百分比0.0%" & check02$organization_id == "331302", "", check02$flag95)
# 
# #私立復興實驗高中(331304)
#   #確實沒有設置輔導室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "331304", "", check02$flag1)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "331304", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：79人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：99；差異百分比20.2%" & check02$organization_id == "331304", "", check02$flag95)
# 
# #私立東方工商(331402)
#   #確實沒有設置教務處主管 輔導室主管 圖書館主管 人事室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：教務處主管 輔導室主管 圖書館主管 人事室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "331402", "", check02$flag1)
#   #呂桂芳（0360220）出生年月日無誤
# check02$flag7 <- if_else(check02$flag7 == "職員(工)資料表：呂桂芳（0360220）（請確認出生年月日是否正確）" & check02$organization_id == "331402", "", check02$flag7)
#   #人事室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "331402", "", check02$flag62)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 == "教員資料表需核對「本校到職日期」：簡偉倫（兼任教師 到職日:1100901）（請依欄位說明，再協助確認是否為本次任職聘書/聘約之到職日期。）" & check02$organization_id == "331402", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：8人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：8；差異百分比0.0%" & check02$organization_id == "331402", "", check02$flag95)
#   #李崇懿，美國	加州大學洛杉磯分校	教育行政
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：李崇懿（碩士學位畢業系所（一）：教育行政）" & check02$organization_id == "331402", "", check02$spe6)
# 
# #私立喬治工商(331403)
#   #確實沒有設置輔導室主管 圖書館主管(暫缺)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "331403", "", check02$flag1)
#   #沒有設置科主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "331403", "", check02$flag2)
#   #放過學校 教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "331403", "", check02$flag18)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "331403", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：19人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：18；差異百分比-5.6%" & check02$organization_id == "331403", "", check02$flag95)
# 
# #私立開平餐飲(331404)
#   #確實沒有設置圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：總務處主管 人事室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "331404", "", check02$flag1)
#   #沒有設置科主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "331404", "", check02$flag2)
#   #該員為技術教師 故最高學歷不為大專以上給過
# check02$flag89 <- if_else(check02$flag89 == "教員資料表：周家銜（請再協助確認渠等人員畢業學歷）" & check02$organization_id == "331404", "", check02$flag89)
#   #該校上一期未上傳資料 故此項不檢查
# check02$flag93 <- if_else(check02$flag93 != "" & check02$organization_id == "331404", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：31人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：51；差異百分比39.2%" & check02$organization_id == "331404", "", check02$flag95)
# 
# #私立大同高中(341302)
#   #確實沒有設置圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "341302", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "341302", "", check02$flag2)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：35人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：35；差異百分比0.0%" & check02$organization_id == "341302", "", check02$flag95)
# 
# #私立稻江護家(341402)
#   #圖書館主管為組長
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "341402", "", check02$flag1)
#   #輔導室主任 實習輔導處主任
# check02$flag18 <- if_else(check02$flag18 == "輔導室主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "341402", "", check02$flag18)
#   #教務處電算中心的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "341402", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：58人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：58；差異百分比0.0%" & check02$organization_id == "341402", "", check02$flag95)
# 
# #私立強恕中學(351301)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：18人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：20；差異百分比10.0%" & check02$organization_id == "351301", "", check02$flag95)
# 
# #臺北市開南高中(351402)
#   #確實沒有設置輔導室主管 圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "351402", "", check02$flag1)
#   #黃崇榮 非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "351402", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：39人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：39；差異百分比0.0%" & check02$organization_id == "351402", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：房佳樺（約聘僱 會計室會計主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "351402", "", check02$flag96)
# 
# #私立南華高中進修學校(351B09)
#   #確實沒有設置圖書館主管 人事室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 人事室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "351B09", "", check02$flag1)
#   #進修學校，主聘單位全部都填"高中部進修部"
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。；教員資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。" & check02$organization_id == "351B09", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：17人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：17；差異百分比0.0%" & check02$organization_id == "351B09", "", check02$flag95)
# 
# #臺北市靜修高中(361301)
#   #確實沒有設置實習處主管 人事室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：實習處主管 人事室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "361301", "", check02$flag1)
#   #沒有設置科主任或學程主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "361301", "", check02$flag2)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag90 <- if_else(check02$flag90 == "姓名：詹坤志（約聘僱）（人事資料顯示該教師兼任行政職務）（校內行政職務原則由專任教師兼任，請協助再確認上述教師是否兼任行政職，或協助再確認上述教師之聘任類別）" & check02$organization_id == "361301", "", check02$flag90)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：78人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：78；差異百分比0.0%" & check02$organization_id == "361301", "", check02$flag95)
# 
# #私立稻江高商(361401)
#   #確實沒有設置圖書館主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "361401", "", check02$flag1)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "361401", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：43人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：34；差異百分比-26.5%" & check02$organization_id == "361401", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：陳怡秀（約聘僱 實習處實習主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "361401", "", check02$flag96)
# 
# #私立志仁中學進修學校(361B09)
#   #圖書館主任編制在總務處下
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "361B09", "", check02$flag1)
#   #放過學校 教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "361B09", "", check02$flag18)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "361B09", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：16人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：13；差異百分比-23.1%" & check02$organization_id == "361B09", "", check02$flag95)
# 
# #私立東山高中(381301)
#   #蔡佩???（兼任行政職服務單位(一)：教務處音樂中心 兼任行政職職稱(一)：組長） 辜姿穎（兼任行政職服務單位(一)：教務處國際中心 兼任行政職職稱(一)：組長），職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "381301", "", check02$flag62)
#   #Cadby Michael Charles  Zwischenberger Trevor James 宋文琳 蕭大衛 辰艾藍皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "381301", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：162人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：181；差異百分比10.5%" & check02$organization_id == "381301", "", check02$flag95)
# 
# #私立滬江高中(381302)
#   #確實沒有設置輔導室主管 圖書館主管 人事室主管 主（會）計室
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管 人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "381302", "", check02$flag1)
#   #輔導室、會計室、人事室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "381302", "", check02$flag62)
#   #胡莉叡 非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "381302", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：31人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：30；差異百分比-3.3%" & check02$organization_id == "381302", "", check02$flag95)
# 
# #私立大誠高中(381303)
#   #放過學校 教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "381303", "", check02$flag18)
#   #榮明杰 趙志仁本學期確實以兼任教師身分兼任行政職務
# check02$flag90 <- if_else(check02$flag90 == "姓名：榮明杰（兼任）（人事資料顯示該教師兼任行政職務） 趙志仁（兼任）（人事資料顯示該教師兼任行政職務）（校內行政職務原則由專任教師兼任，請協助再確認上述教師是否兼任行政職，或協助再確認上述教師之聘任類別）" & check02$organization_id == "381303", "", check02$flag90)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：19人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：23；差異百分比17.4%" & check02$organization_id == "381303", "", check02$flag95)
#   #趙志仁確實已兼任教師身分兼任人事主任
# check02$flag96 <- if_else(check02$flag96 == "教員資料表：趙志仁（兼任 人事室人事主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "381303", "", check02$flag96)
# 
# #私立再興中學(381304)
#   #確實沒有設置圖書館主管，僅有組長
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "381304", "", check02$flag1)
#   #圖書室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "381304", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：91人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：91；差異百分比0.0%" & check02$organization_id == "381304", "", check02$flag95)
# 
# #私立景文高中(381305)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "381305", "", check02$flag80)
#   #HALVERSONBrodyDEAN John Jeffrey Linskey MICHAEL Nicholas Anthony Corasaniti 吳昌彥 吳麗明 周宜瑾 巫美娟 張崑堯 張禮秀 蔡有忠 郭筱璇 黃靜怡 皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "381305", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：77人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：76；差異百分比-1.3%" & check02$organization_id == "381305", "", check02$flag95)
# 
# #臺北市靜心高中(381306)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：王舒葳（約聘僱 英語中心主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "381306", "", check02$flag96)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：65人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：72；差異百分比9.7%" & check02$organization_id == "381306", "", check02$flag95)
# 
# #私立文德女中(401301)
#   #確實沒有設置教務處主管 學務處主管 總務處主管 輔導室主管 圖書館主管 人事室主管 主（會）計室主管(將停招)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：教務處主管 學務處主管 總務處主管 輔導室主管 圖書館主管 人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "401301", "", check02$flag1)
#   #放過學校 教員資料表專任教學人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "401301", "", check02$flag18)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "401301", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：5人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：5；差異百分比0.0%" & check02$organization_id == "401301", "", check02$flag95)
# 
# #私立方濟中學(401302)
#   #確實沒有設置圖書館主管 主（會）計室主管，僅分別設有管理員、會計員
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "401302", "", check02$flag1)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：16人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：16；差異百分比0.0%" & check02$organization_id == "401302", "", check02$flag95)
# 
# #私立達人女中(401303)
#   #主（會）計室主管暫缺
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "401303", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "401303", "", check02$flag18)
#   #會計室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "401303", "", check02$flag62)
#   #廖俊幃 王彩蓁 皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "401303", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：55人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：53；差異百分比-3.8%" & check02$organization_id == "401303", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：吳景蓉（約聘僱 總務處主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "401303", "", check02$flag96)
# 
# #私立泰北高中(411301)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "411301", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：47人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：46；差異百分比-2.2%" & check02$organization_id == "411301", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "職員(工)資料表：胡坤宏（約聘僱 學生事務處學務主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "411301", "", check02$flag96)
# 
# #私立衛理女中(411302)
#   #確實沒有設置人事室主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "411302", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "411302", "", check02$flag18)
#   #住校處的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "411302", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：69人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：79；差異百分比12.7%" & check02$organization_id == "411302", "", check02$flag95)
# 
# #私立華岡藝校(411401)
#   #確實沒有設置圖書館主管 實習處主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "411401", "", check02$flag1)
#   #放過學校 教員資料表專任教學人員人數偏低 一年以上與任教領域相關之業界實務工作經驗人數偏多
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。一年以上與任教領域相關之業界實務工作經驗人數偏多（請再協助確認，『是否具備一年以上與任教領域相關之業界實務工作經驗』填寫『Y』之教員，是否確依欄位說明具備此經驗）" & check02$organization_id == "411401", "", check02$flag18)
#   #黃凱群 非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "411401", "", check02$flag86)
#   #陳柏安 在上學年填報後到職
# check02$flag93 <- if_else(check02$flag93 == "離退教職員(工)資料表：陳柏安（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年8月1日-112年1月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）" & check02$organization_id == "411401", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：32人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：28；差異百分比-14.3%" & check02$organization_id == "411401", "", check02$flag95)
#   #范昌瑾（碩士學位畢業學校（一）：NEW ENGLAND CONSERVATORY OF MUSIC） 黃翠屏（碩士學位畢業學校（一）：CONSERVATORIO STATALE DIMILANO“GIUSEPPEVERDI”ITALIA）正確
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：范昌瑾（碩士學位畢業學校（一）：NEWENGLANDCONSERVATORYOFMUSIC） 黃翠屏（碩士學位畢業學校（一）：CONSERVATORIOSTATALEDIMILANO“GIUSEPPEVERDI”ITALIA）" & check02$organization_id == "411401", "", check02$spe6)
# 
# #私立薇閣高中(421301)
#   #確實沒有設置圖書館主管 人事室主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 人事室主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "421301", "", check02$flag1)
#   #國際部、會計室、人事室的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "421301", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：145人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：130；差異百分比-11.5%" & check02$organization_id == "421301", "", check02$flag95)
# 
# #臺北市幼華高中(421302)
#   #確實沒有設置圖書館主管 實習處主管 主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管 實習處主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "421302", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "421302", "", check02$flag18)
#   #兼任教師、鐘點教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "421302", "", check02$flag80)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：48人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：50；差異百分比4.0%" & check02$organization_id == "421302", "", check02$flag95)
# 
# #臺北市私立奎山實驗高級中學(421303)
#   #確實沒有設置教務處主管 輔導室主管 圖書館主管 主（會）計室主管，中學部主任兼任教務主任及輔導主任(沒有設教務處及輔導室)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：教務處主管 輔導室主管 圖書館主管 主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "421303", "", check02$flag1)
#   #放過學校 職員(工)資料表主聘單位各類別人數分布異常(奎山為實驗學校，不容易區分高中部或中學部，故有4位填"其他"，)
#     # 夏荻	人事室	行政秘書
#     # 馮臨燕	人事室	代理主任
#     # 曾台郇	總務處	總務組長
#     # 杜欣祐	圖書館	組長
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。" & check02$organization_id == "421303", "", check02$flag18)
#   #圖書館的主管為組長，職稱無誤
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "421303", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：25人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：23；差異百分比-8.7%" & check02$organization_id == "421303", "", check02$flag95)
#   #英文學校名稱無誤
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：Peter Williams（碩士學位畢業學校（一）：BIBLICALINTERPRETATIONLONDONSCHOOLOFTHEOLOGY）； 職員(工)資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：夏荻（碩士學位畢業學校（一）：DALLASBAPTISTUNIV.）" & check02$organization_id == "421303", "", check02$spe6)
# 
# #私立惇敘工商(421404)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：30人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：29；差異百分比-3.4%" & check02$organization_id == "421404", "", check02$flag95)
# 
# #天主教明誠高中(521301)
#   #確實沒有設置實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "521301", "", check02$flag1)
#   #沒有設置科主任
# check02$flag2 <- if_else(check02$flag2 == "請學校確認是否設置科主任或學程主任" & check02$organization_id == "521301", "", check02$flag2)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：58人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：67；差異百分比13.4%" & check02$organization_id == "521301", "", check02$flag95)
# 
# #私立大榮高中(521303)
#   #教員王昭月 兼任圖書館主任(圖書館主任隸屬於教務處)
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "521303", "", check02$flag1)
#   #教務處設有英語發展中心主任及高中部主任 總務處設有總務主任及國小總務主任
# check02$flag18 <- if_else(check02$flag18 == "教務處主管（主任）人數超過一位，請再協助確認實際聘任情況。總務處主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "521303", "", check02$flag18)
#   #李光庭（兼任行政職服務單位(一)：國小總務處） 正確
# check02$flag62 <- if_else(check02$flag62 != "" & check02$organization_id == "521303", "", check02$flag62)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：50人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：51；差異百分比2.0%" & check02$organization_id == "521303", "", check02$flag95)
# 
# #私立中華藝校(521401)
#   #確實沒有設置輔導室主管 圖書館主管 實習處主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：輔導室主管 圖書館主管 實習處主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "521401", "", check02$flag1)
#   #放過學校 教員資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "521401", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：43人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：47；差異百分比8.5%" & check02$organization_id == "521401", "", check02$flag95)
# 
# #私立立志高中(551301)
#   #確實沒有設置主（會）計室主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "551301", "", check02$flag1)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：89人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：102；差異百分比12.7%" & check02$organization_id == "551301", "", check02$flag95)
# 
# #私立樹德家商(551402)
#   #確實沒有設置圖書館主管
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：圖書館主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "551402", "", check02$flag1)
#   #兼任教師連續聘任不中斷無誤
# check02$flag80 <- if_else(check02$flag80 != "" & check02$organization_id == "551402", "", check02$flag80)
#   #倪寶珠 劉嘉珺 林秀敏 王靜怡 陳怡婷 陳樺亭 皆非本學期退休或因故離職人員
# check02$flag86 <- if_else(check02$flag86 != "" & check02$organization_id == "551402", "", check02$flag86)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：148人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：151；差異百分比2.0%" & check02$organization_id == "551402", "", check02$flag95)
# 
# #私立復華高中(581301)
#   #放過學校
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。；教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。" & check02$organization_id == "581301", "", check02$flag18)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：63人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：59；差異百分比-6.8%" & check02$organization_id == "581301", "", check02$flag95)
# 
# #天主教道明中學(581302)
#   #王雅瑩	教務處	音樂教育中心主任
#   #楊嘉欽	教務處	教務主任
#   #蔡達源	教務處	美術教育中心主任
# check02$flag18 <- if_else(check02$flag18 == "教務處主管（主任）人數超過一位，請再協助確認實際聘任情況。" & check02$organization_id == "581302", "", check02$flag18)
#   #施德敏 曾淑媛 李淑蘭 王順利 芮耀斌 賴美玲在上學年填報後到職
# check02$flag93 <- if_else(check02$flag93 == "離退教職員(工)資料表：施德敏 曾淑媛 李淑蘭 王順利 芮耀斌 賴美玲 高世錦（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年8月1日-112年1月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）" & check02$organization_id == "581302", "", check02$flag93)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：163人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：158；差異百分比-3.2%" & check02$organization_id == "581302", "", check02$flag95)
#   #李昱萱（碩士學位畢業學校（一）：NEWYORK FILM ACEDEMY）正確
# check02$spe6 <- if_else(check02$spe6 == "教員資料表之大學（學士）以上各教育階段學歷資料不完整或不正確：李昱萱（碩士學位畢業學校（一）：NEWYORKFILMACEDEMY）" & check02$organization_id == "581302", "", check02$spe6)
# 
# #私立三信家商(581402)
#   #主（會）計室主管暫缺
# check02$flag1 <- if_else(check02$flag1 == "尚待增補之學校主管：主（會）計室主管（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）" & check02$organization_id == "581402", "", check02$flag1)
#   #放過學校 職員(工)資料表專任人員人數偏低
# check02$flag18 <- if_else(check02$flag18 == "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。" & check02$organization_id == "581402", "", check02$flag18)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag90 <- if_else(check02$flag90 == "姓名：徐文玲（約聘僱）（人事資料顯示該教師兼任行政職務）（校內行政職務原則由專任教師兼任，請協助再確認上述教師是否兼任行政職，或協助再確認上述教師之聘任類別）" & check02$organization_id == "581402", "", check02$flag90)
#   #本項目不需請學校修正
# check02$flag95 <- if_else(check02$flag95 == "統計處專任教師人數：64人；本資料庫專任教師、代理教師、校長、教官、主任教官人數：63；差異百分比-1.6%" & check02$organization_id == "581402", "", check02$flag95)
#   #約聘僱可算全職，可暫不請學校修正
# check02$flag96 <- if_else(check02$flag96 == "教員資料表：徐文玲（約聘僱 實習處科主任）； 職員(工)資料表：劉志文（約聘僱 總務處主任）（約聘僱 人事室主任） 謝政達（約聘僱 學務處主任） 邱士賢（約聘僱 招生中心主任）（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）" & check02$organization_id == "581402", "", check02$flag96)


check02$err_flag <- 0

temp <- c("flag1", "flag2", "flag3", "flag6", "flag7", "flag8", "flag9", "flag15", "flag16", "flag18", "flag19", "flag20", "flag24", "flag39", "flag45", "flag47", "flag48", "flag49", "flag50", "flag51", "flag52", "flag57", "flag59", "flag62", "flag64", "flag80", "flag82", "flag83", "flag84", "flag85", "flag86", "flag89", "flag90", "flag91", "flag92", "flag93", "flag94", "flag95", "flag96", "flag97", "flag98", "flag99", "flag100", "spe3", "spe5", "spe6")
for (i in temp){
  check02[[i]] <- if_else(is.na(check02[[i]]), "", check02[[i]])
  check02$err_flag <- if_else(nchar(check02[[i]]) != 0, 1, check02$err_flag)
}

#刪除無錯誤的學校
check02 <- check02 %>%
  subset(err_flag != 0)

if (dim(check02)[1] != 0){
#標誌出無錯誤的處室
check02$err_flag_P <- 0
check02$err_flag_Ps <- 0
for (i in temp){
  check02$err_flag_P <- if_else(check02[[i]] == "", 1, check02$err_flag_P)
  check02$err_flag_Ps <- if_else(check02[[i]] != "", 1 + check02$err_flag_Ps, check02$err_flag_Ps)
}

check02$err_flag_Ps <- check02$err_flag_Ps %>% as.character()

check02$flag_P_txt <- if_else(
  check02$err_flag_P == 0, "貴處室提供的資料，沒有檢查出需要修正之處。謝謝貴處室協助完成填報工作，請等待其他處室重新上傳資料，如果處室間資料比對有誤，系統會再發信通知。謝謝！",
  paste0("經本計畫複檢，仍發現共有",  check02$err_flag_Ps,  "個可能需要修正之處，懇請貴處室協助增補，尚祈見諒！修正後的檔案需重新完成整個填報流程。如有疑問，請與本計畫人員聯繫，謝謝！")
  )

for (i in temp){
  for (j in 1:dim(check02)[1]){
    check02[[i]][j] <- if_else(check02[[i]][j] == "", "通過", check02[[i]][j])
  }
}

check02 <- check02 %>%
  subset(select = -c(err_flag, err_flag_P, err_flag_Ps))
openxlsx :: write.xlsx(check02, file = "C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx", rowNames = FALSE, overwrite = TRUE)
}else{
openxlsx :: write.xlsx(check02, file = "C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx", rowNames = FALSE, overwrite = TRUE)
}

#####自動化檢誤#####
#若全部學校皆未上傳(print檔案不存在 或 自己管區的學校皆未上傳)，以下皆不執行
if(!file.exists(checkfile_server) | #print檔案不存在
   (check02 %>% select("organization_id") %>% subset(organization_id %in% dis) %>% dim())[1] == 0) # 或 自己管區的學校皆未上傳
{
  print("所有學校皆尚未上傳資料")
}else
{
  #####自動化通知 - 每小時通知<本次上傳學校名單、需補正學校名單、三階檢通過學校名單>#####
  #初次執行需建立pre_list_agree和pre_correct_list兩個xlsx檔，用if else來做
  #若xlsx檔不存在，建立檔案
  if(!file.exists("C:/edhr-112t1/dta/edhr_112t1-202310/pre_list_agree_人事.xlsx"))
  {
    #建立pre_list_agree.xlsx
    pre_list_agree <- list_agree
    openxlsx :: write.xlsx(pre_list_agree, file = "C:/edhr-112t1/dta/edhr_112t1-202310/pre_list_agree_人事.xlsx", rowNames = FALSE, overwrite = TRUE)
    #建立pre_correct_list.xlsx
    correct_list <- readxl :: read_excel("C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx") %>% #本次需補正學校
      subset(select = c(organization_id, edu_name2))
    correct_list$edu_name2 <- paste(correct_list$edu_name2, "(", correct_list$organization_id, ")", sep = "")
    correct_list <- correct_list %>%
      mutate(pre_correct = 1)
    #以下是為了解決無法合併的問題
    if(dim(correct_list)[1] == 0)
    {
      correct_list[1, 1 : 2] = "0"
      colnames(correct_list) <- c("organization_id", "edu_name2", "pre_correct")
    }else
    {
      correct_list = correct_list
    }
    openxlsx :: write.xlsx(correct_list, file = "C:/edhr-112t1/dta/edhr_112t1-202310/pre_correct_list_人事.xlsx", rowNames = FALSE, overwrite = TRUE)
  }else
  {
    print("pre_list_agree和pre_correct_list兩個xlsx檔存在，繼續執行")
  }
  
  #若xlsx檔存在，執行
  if(file.exists("C:/edhr-112t1/dta/edhr_112t1-202310/pre_list_agree_人事.xlsx"))
  {
    #讀取上次名單
    pre_list_agree <- readxl :: read_excel("C:/edhr-112t1/dta/edhr_112t1-202310/pre_list_agree_人事.xlsx")
    pre_list_agree$organization_id <- as.character(pre_list_agree$organization_id)
    pre_correct_list <- readxl :: read_excel("C:/edhr-112t1/dta/edhr_112t1-202310/pre_correct_list_人事.xlsx")
    pre_correct_list <- mutate(pre_correct_list, pre_correct = 1)
    #以下是為了解決pre_list_agree無法合併的問題(若出現此問題只會發生在list_agree為空 且 pre_list_agree為空)
    if(dim(pre_list_agree)[1] == 0 & dim(list_agree)[1] == 0)
    {
      pre_list_agree <- list_agree
    }else
    {
      pre_list_agree = pre_list_agree
    }
    
    #本次上傳 - 本次出現但上次沒出現
    organization <- readxl :: read_excel("\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\1112私立學校名單.xls") %>% #[每次填報更改]本次填報的學校名單檔案路徑
      select("organization_id", "edu_name") %>%
      rename(name = edu_name)
    compare_list <- left_join(list_agree, pre_list_agree, by = c("organization_id")) %>%
      subset(is.na(agree.y))
    compare_list <- merge(x = compare_list, y = organization, by = "organization_id", all.x = TRUE)
    #以下是為了解決compare_list為0
    if(dim(compare_list)[1] == 0)
    {
      compare_list[1, 1 : 4] = 0
    }else
    {
      compare_list = compare_list
    }
    compare_list$name <- paste(compare_list$name, "(", compare_list$organization_id, ")", sep = "")
    
    #本次上傳 - 本次出現且上次出現且出現在上次需修正名單(compare_correct_list的意思是在這次上傳期間未處理上次未通過的學校)
    compare_correct_list <- left_join(list_agree, pre_correct_list, by = c("organization_id")) %>%
      subset(pre_correct == 1)
    #以下是為了解決compare_correct_list為0
    if(dim(compare_correct_list)[1] == 0)
    {
      compare_correct_list[1, 1 : 4] = 0
    }else
    {
      compare_correct_list = compare_correct_list
    }
    
    #compare_correct_list$edu_name2 <- paste(compare_correct_list$edu_name2, "(", compare_correct_list$organization_id, ")", sep = "")
    #另存'本次已上傳名單"，以便於與下次名單比對
    pre_list_agree <- list_agree
    openxlsx :: write.xlsx(pre_list_agree, file = "C:/edhr-112t1/dta/edhr_112t1-202310/pre_list_agree_人事.xlsx", rowNames = FALSE, overwrite = TRUE)
    
    correct_list <- readxl :: read_excel("C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx") %>% #本次需補正學校
      subset(select = c(organization_id, edu_name2))
    correct_list_c <- correct_list %>%
      subset(select = c(organization_id))
    correct_list$edu_name2 <- paste(correct_list$edu_name2, "(", correct_list$organization_id, ")", sep = "")
    
    #處理correct_list為tibble的問題
    if(dim(correct_list)[1] == 0){
      correct_list <- data.frame(
        organization_id = c(""), 
        edu_name2 = c("")
      )
      correct_list <- correct_list[-1, ]
    }else{
      correct_list <- correct_list
    }
    #將correct_list_c 變數的data type改為char
    if(is.character(correct_list_c$organization_id)){
      correct_list_c <- correct_list_c
    }else{
      correct_list_c <- correct_list_c %>% mutate(across(organization_id, as.character))
    }
    correct_list <- left_join(compare_list, correct_list, by = c("organization_id")) %>%
      subset(select = c(organization_id, edu_name2)) %>%
      subset(!is.na(edu_name2))
    correct_list_2 <- left_join(correct_list_c, compare_correct_list, by = c("organization_id")) %>%
      subset(select = c(organization_id, edu_name2, pre_correct)) %>%
      subset(pre_correct == 1)
    correct_list <- bind_rows(correct_list, correct_list_2)
    correct <- apply(as.data.frame(correct_list$edu_name2), 2, paste, collapse = ", ")
    
    #用stata將學校三階檢未通過改為通過之處理
    #出現在上次需修正名單(pre_correct_list) 且未出現在本次需修正名單(correct_list) 且出現在compare_correct_list，則從compare_correct_list刪除
    #也就是我不要pre_correct_list == 1 & is.na(correct_list) & compare_correct_list == 1
    compare_correct_list <- compare_correct_list %>%
      mutate(compare_correct_list = 1)
    pre_correct_list_c <- pre_correct_list %>%
      mutate(pre_correct_list = 1)
    correct_list_c <- correct_list
    #以下是為了解決correct_list_c無法合併的問題
    if(dim(correct_list_c)[1] == 0)
    {
      correct_list_c[1, 1 : 2] = 0
      colnames(correct_list_c) <- c("organization_id", "edu_name2", "pre_correct")
    }else
    {
      correct_list_c = correct_list_c
    }
    correct_list_c <- correct_list_c %>%
      mutate(correct_list = 1)
    compare_correct_list <- merge(x = compare_correct_list, y = pre_correct_list_c, by = "organization_id", all = TRUE)
    compare_correct_list <- merge(x = compare_correct_list, y = correct_list_c, by = "organization_id", all = TRUE)
    compare_correct_list <- compare_correct_list %>%
      subset(compare_correct_list != 1 | pre_correct != 1 | !is.na(correct_list)) #By De Morgan' s Laws, (A交集B交集C)的補集合 = A補集合或B補集合或C補集合
    compare_correct_list <- compare_correct_list %>%
      subset(select = c(organization_id, agree, edu_name2.x, pre_correct.x)) %>%
      rename(edu_name2 = edu_name2.x, pre_correct = pre_correct.x)
    
    #以下是為了解決無法合併的問題
    if(dim(correct_list)[1] == 0)
    {
      correct_list[1, 1 : 2] = 0
      colnames(correct_list) <- c("organization_id", "edu_name2", "pre_correct")
    }else
    {
      correct_list = correct_list
    }
    
    #以下是為了解決correct開頭為","
    str_corr <- str_locate(correct, ",")[ ,1]
    
    if(is.na(str_corr))
    {
      str_corr = " "
    }else
    {
      str_corr = str_corr
    }
    
    if(str_corr == 1)
    {
      correct = substr(correct, start = 2, stop = nchar(correct))  
    }else
    {
      correct = correct
    }
    
    #建立表格內容會用到的學校名單
    now <- apply(as.data.frame(compare_list$name), 2, paste, collapse = ", ") #本次上傳學校
    #以下是為了解決now為0(0)
    if(now == "0(0)")
    {
      now = ""
    }else
    {
      now = now
    }
    now <- paste(now, apply(as.data.frame(compare_correct_list$edu_name2), 2, paste, collapse = ", "), sep = ", ")
    
    #以下是為了解決now開頭為","
    str_now <- str_locate(now, ",")[ ,1]
    
    if(is.na(str_now))
    {
      str_now = " "
    }else
    {
      str_now = str_now
    }
    
    if(str_now == 1)
    {
      now = substr(now, start = 2, stop = nchar(now))  
    }else
    {
      now = now
    }
    #以下是為了解決now為0
    if(now == "0")
    {
      now = ""
    }else
    {
      now = now
    }
    
    #以下是為了解決now為 0
    if(now == " 0")
    {
      now = ""
    }else
    {
      now = now
    }
    
    #以下是為了解決now結尾為", 0"
    str_now <- str_locate(now, ", 0")[ ,1]
    
    if(!is.na(str_now) & now != "")
    {
      now = substr(now, start = 1, stop = nchar(now) - 3)
    }else
    {
      now = now
    }
    
    #以下是為了解決now結尾為", NA"
    if(is.na(str_locate(now, ", NA")[ ,1])){
      now = now
    }else if(str_locate(now, ", NA")[ ,1] == nchar(now) - 3){
      now = substr(now, start = 1, stop = nchar(now) - 4)
    }else{
      now = now
    }
    
    #另存'本次需修正名單"，以便於與下次名單比對
    openxlsx :: write.xlsx(correct_list, file = "C:/edhr-112t1/dta/edhr_112t1-202310/pre_correct_list_人事.xlsx", rowNames = FALSE, overwrite = TRUE)
    
    clear_list <- left_join(compare_list, correct_list, by = c("organization_id")) %>% #本次三階檢通過學校
      subset(select = c(organization_id, edu_name2, name)) %>%
      subset(is.na(edu_name2)) 
    clear <-apply(as.data.frame(clear_list$name), 2, paste, collapse = ", ")
    clear_correct_list <- merge(x = correct_list, y = pre_correct_list, by = c("organization_id"), all = TRUE) %>%
      subset(is.na(edu_name2.x)) %>%
      subset(select = c(organization_id, edu_name2.y))
    clear_correct_list <- merge(x = clear_correct_list , y = pre_correct_list, by = c("organization_id"), all.x = TRUE) %>%  #clear_correct_list: 沒出現在correct_list 且出現在pre_correct_list，可能為(1)本次通過且上次未通過 或(2)本次被退件且上次未通過，需排除(2)，也就是clear_correct_list的名單若也出現在pre_correct_list，需排除
      subset(is.na(edu_name2)) %>%
      subset(select = c(organization_id, edu_name2.y))
    #以下是為了解決clear_correct_list為0
    if(dim(clear_correct_list)[1] == 0)
    {
      clear_correct_list[1, 1 : 2] = 0
    }else
    {
      clear_correct_list = clear_correct_list
    }
    
    clear_correct_list$edu_name2.y <- substr(clear_correct_list$edu_name2.y, start = 1, stop = str_locate(clear_correct_list$edu_name2.y, pattern = "\\(")[1, 1] - 1)
    clear_correct_list$edu_name2.y <- paste(clear_correct_list$edu_name2.y, "(", clear_correct_list$organization_id, ")", sep = "")
    clear_2 <-apply(as.data.frame(clear_correct_list$edu_name2.y), 2, paste, collapse = ", ")
    clear <- paste(clear, clear_2, sep = ",")
    
    #以下是為了解決clear開頭為","
    if(str_locate(clear, ",")[ ,1] == 1)
    {
      clear = substr(clear, start = 2, stop = nchar(clear))  
    }else
    {
      clear = clear
    }
    
    #以下是為了解決"0(0)"
    if(now == "0(0)")
    {
      now = ""
    }else
    {
      now = now
    }
    
    #以下是為了解決now中間出現NA
    now <- gsub(", NA", "", now)
    
    if(correct == "0(0)")
    {
      correct = ""
    }else
    {
      correct = correct
    }
    
    #以下是為了解決"NA(0)"
    if(clear == "NA(0)")
    {
      clear = ""
    }else
    {
      clear = clear
    }
    
    #以下是為了解決clear出現,NA(0)
    clear <- gsub(",NA\\(0\\)", "", clear)
    
    #以下是為了解決clear為"0(0)"
    if(clear == "0(0)")
    {
      clear = ""
    }else
    {
      clear = clear
    }
    
    #以下是為了解決now為" NA"
    now <- gsub(" NA", "", now)
    
    #excel視窗通知
    #先判斷check_print檔案是否使用中(以"是否可更改檔案名稱"來判斷 若可更改 代表未使用中)
    checkprint_filename <- "C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx"
    checkprint_filename_2 <- substr(checkprint_filename, start = 1, stop = str_locate(checkprint_filename, ".xlsx")[ ,1] - 1)  
    
    if(file.rename(from = checkprint_filename, to = paste(checkprint_filename_2, "2.xlsx", sep = "")) == TRUE)
    {
      if(nchar(now) == 0)
      {
        file.rename(from = paste(checkprint_filename_2, "2.xlsx", sep = ""), to = checkprint_filename)
        
        paste(format(time_now, format = "%Y/%m/%d %H:%M"), " 本次無學校上傳", sep = "")
      }else
      {
        #存入xlsx，自動開啟
        #建立檔案名稱
        correct_filename_year <- substr(title, start = str_locate(title, "學年度")[ ,1] - 3, stop = str_locate(title, "學年度")[ ,1] - 1)
        if(substr(title, start = str_locate(title, "學期")[ ,1] - 1, stop = str_locate(title, "學期")[ ,1] - 1) == "上")
        {
          correct_filename_sem <- "1"
        }else{
          correct_filename_sem <- "2"
        }
        correct_filename_name <- substr(title, start = str_locate(title, "（")[ ,1] + 1, stop = str_locate(title, "）")[ ,1] - 1)
        correct_filename <- paste(correct_filename_year, correct_filename_sem, correct_filename_name, "_上傳名單", sep = "")
        
        #建立fileopen.bat
        write.table(paste("start C:\\autochecking\\",correct_filename, ".xlsx", sep = ""), file = "C:\\autochecking\\fileopen.bat", append = FALSE, quote = FALSE, col.names = FALSE, row.names = FALSE, fileEncoding = "BIG5")
        
        if(!file.exists(paste("C:\\autochecking\\",correct_filename, ".xlsx", sep = "")))
        {
          #如果檔案不存在
          # 建立 Excel 活頁簿
          wb <- createWorkbook()
          
          # 設定框線樣式
          options("openxlsx.borderColour" = "#4F80BD")
          options("openxlsx.borderStyle" = "thin")
          
          # 設定 Excel 活頁簿預設字型
          modifyBaseFont(wb, fontSize = 20, fontName = "Arial")
          
          # 新增工作表
          addWorksheet(wb, sheetName = "上傳名單", gridLines = FALSE)
          
          # 建立上傳學校名單表格
          body <- data.frame(matrix(0, 1, 4))
          colnames(body) <- c("上傳時間", "本次上傳學校", "本次需補正學校", "本次三階檢通過學校")
          body[1, ] <- c(format(time_now, format = "%Y/%m/%d %H:%M"), now, correct, clear)
          
          # 建立樣式
          headSty <- createStyle(fontSize = 22, fgFill="#DCE6F1", halign="center", border = "TopBottomLeftRight", wrapText = TRUE)
          
          # 將學校名單表格寫入
          txtSty <- createStyle(halign="left", valign = "center", border = "TopBottomLeftRight", wrapText = TRUE)
          writeData(wb, 1, x = body, startCol = "A", startRow=1, borders="rows", headerStyle = headSty)
          addStyle(wb, sheet = 1, style = txtSty, cols = 1:4, rows = 2:(dim(body)[1]+1), gridExpand = TRUE)
          
          # 設定欄寬
          setColWidths(wb, 1, cols=1, widths = 16)
          setColWidths(wb, 1, cols=2:5, widths = 20)
          
          # 儲存 Excel 活頁簿
          saveWorkbook(wb, paste("C:\\autochecking\\",correct_filename, ".xlsx", sep = ""), overwrite = TRUE)
          
          # excel檔開啟30秒後自動關閉
          time_a <- Sys.time()
          a <- as.numeric(format(time_a, format = "%M")) * 60 + as.numeric(format(time_a, format = "%S"))      
          shell.exec("C:\\autochecking\\fileopen.bat")
          
          b <- a
          while (b - a < 30)
          {
            time_b <- Sys.time()
            b <- as.numeric(format(time_b, format = "%M")) * 60 + as.numeric(format(time_b, format = "%S"))
          }
          
          if(!file.exists("C:\\autochecking\\fileclose.bat"))
          {
            write.table(paste("taskkill /FI \"WINDOWTITLE eq ", correct_filename, "*\"", sep = ""), file = "C:\\autochecking\\fileclose.bat", append = FALSE, quote = FALSE, col.names = FALSE, row.names = FALSE)
          }else
          {
            print("建立fileclose.bat檔案")
          }
          
          shell.exec("C:\\autochecking\\fileclose.bat")
        }else{
          #如果檔案存在
          # 建立 Excel 活頁簿
          wb <- createWorkbook()
          
          # 設定框線樣式
          options("openxlsx.borderColour" = "#4F80BD")
          options("openxlsx.borderStyle" = "thin")
          
          # 設定 Excel 活頁簿預設字型
          modifyBaseFont(wb, fontSize = 20, fontName = "Arial")
          
          # 新增工作表
          addWorksheet(wb, sheetName = "上傳名單", gridLines = FALSE)
          
          # 建立上傳學校名單表格
          body <- readxl :: read_excel(paste("C:\\autochecking\\",correct_filename, ".xlsx", sep = ""))
          body <- rbind(c("0", "0", "0", "0"), body)
          colnames(body) <- c("上傳時間", "本次上傳學校", "本次需補正學校", "本次三階檢通過學校")
          body[1, ] <- as.list(c(format(time_now, format = "%Y/%m/%d %H:%M"), now, correct, clear))
          
          # 建立樣式
          headSty <- createStyle(fontSize = 22, fgFill="#DCE6F1", halign="center", border = "TopBottomLeftRight", wrapText = TRUE)
          
          # 將學校名單表格寫入
          txtSty <- createStyle(halign="left", valign = "center", border = "TopBottomLeftRight", wrapText = TRUE)
          writeData(wb, 1, x = body, startCol = "A", startRow=1, borders="rows", headerStyle = headSty)
          addStyle(wb, sheet = 1, style = txtSty, cols = 1:4, rows = 2:(dim(body)[1]+1), gridExpand = TRUE)
          
          # 設定欄寬
          setColWidths(wb, 1, cols=1, widths = 16)
          setColWidths(wb, 1, cols=2:5, widths = 20)
          
          # 儲存 Excel 活頁簿
          saveWorkbook(wb, paste("C:\\autochecking\\",correct_filename, ".xlsx", sep = ""), overwrite = TRUE)
          
          # excel檔開啟30秒後自動關閉
          time_a <- Sys.time()
          a <- as.numeric(format(time_a, format = "%M")) * 60 + as.numeric(format(time_a, format = "%S"))      
          shell.exec("C:\\autochecking\\fileopen.bat")
          
          b <- a
          while (b - a < 30)
          {
            time_b <- Sys.time()
            b <- as.numeric(format(time_b, format = "%M")) * 60 + as.numeric(format(time_b, format = "%S"))
          }
          
          write.table(paste("taskkill /FI \"WINDOWTITLE eq ", correct_filename, "*\"", sep = ""), file = "C:\\autochecking\\fileclose.bat", append = FALSE, quote = FALSE, col.names = FALSE, row.names = FALSE, fileEncoding = "BIG5")
          
          shell.exec("C:\\autochecking\\fileclose.bat")
          
          file.rename(from = "C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事2.xlsx", to = "C:\\edhr-112t1\\work\\edhr-112t1-check_print-人事.xlsx")
        }
      }
    }else
    {
      #建立errortext_fileopen.bat
      if(!file.exists("C:\\autochecking\\errortext_fileopen.bat"))
      {
        write.table("start C:\\autochecking\\errortext_fileopen.xlsx", file = "C:\\autochecking\\errortext_fileopen.bat", append = FALSE, quote = FALSE, col.names = FALSE, row.names = FALSE)
        print("建立errortext_fileopen.bat檔案")
      }else
      {
        print("errortext_fileopen.bat檔案存在")
      }
      
      #如果檔案不存在
      # 建立 Excel 活頁簿
      wb <- createWorkbook()
      
      # 設定框線樣式
      options("openxlsx.borderColour" = "#4F80BD")
      options("openxlsx.borderStyle" = "thin")
      
      # 設定 Excel 活頁簿預設字型
      modifyBaseFont(wb, fontSize = 20, fontName = "Arial")
      
      # 新增工作表
      addWorksheet(wb, sheetName = "上傳名單", gridLines = FALSE)
      
      # 建立上傳學校名單表格
      body <- "本次自動化檢核未執行，請盡速關閉檢核報告word檔，自動化檢核方可繼續執行。閱讀完畢請關閉此檔案。"
      
      # 建立樣式
      headSty <- createStyle(fontSize = 22, fgFill="#DCE6F1", halign="center", border = "TopBottomLeftRight", wrapText = TRUE)
      
      # 將學校名單表格寫入
      txtSty <- createStyle(halign="left", valign = "center", border = "TopBottomLeftRight", wrapText = TRUE)
      writeData(wb, 1, x = body, startCol = "A", startRow=1, borders="rows", headerStyle = headSty)
      addStyle(wb, sheet = 1, style = txtSty, cols = 1:5, rows = 1, gridExpand = TRUE)
      mergeCells(wb, sheet = 1, cols = 1:5, rows = 1:1)
      
      # 設定欄寬
      setColWidths(wb, 1, cols=1, widths = 16)
      setColWidths(wb, 1, cols=2:5, widths = 20)
      
      # 儲存 Excel 活頁簿
      saveWorkbook(wb, "C:\\autochecking\\errortext_fileopen.xlsx", overwrite = TRUE)
      shell.exec("C:\\autochecking\\errortext_fileopen.bat")
    }
  }else
  {
    print("pre_list_agree和pre_correct_list兩個xlsx檔不存在")
  }
}