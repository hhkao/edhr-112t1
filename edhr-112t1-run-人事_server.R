rm(list=ls())

# 載入所需套件
  library(DBI)
  library(odbc)
  library(magrittr)
  library(dplyr)
  library(readxl)
  library(stringr)
  library(openxlsx)
  library(tidyr)
  library(reshape2)
  library(scales)

# 匯入學校資料檔 -------------------------------------------------------------------
# input data
# 分頁名稱為系統指定。

#資料讀取#
#連線
source("connection.R")
#edhr <- dbConnect(odbc::odbc(), "CHER04-TIPEDSTG", timeout = 10)

#請輸入本次填報設定檔標題(字串需與標題完全相符，否則會找不到)
title <- "112學年度上學期高級中等學校教育人力資源資料庫（全國學校人事）"

department <- "人事室"

#讀取審核同意之學校名單
list_agree <- dbGetQuery(edhr, 
                         paste("
SELECT DISTINCT b.id AS organization_id , 1 AS agree
FROM [plat5_edhr].[dbo].[teacher_fillers] a 
LEFT JOIN 
(SELECT a.reporter_id, c.id
FROM [plat5_edhr].[dbo].[teacher_fillers] a LEFT JOIN [plat5_edhr].[dbo].[teacher_reporters] b ON a.reporter_id = b.id
LEFT JOIN [plat5_edhr].[dbo].[organization_details] c ON b.organization_id = c.organization_id
) b ON a.reporter_id = b.reporter_id
WHERE a.agree = 1 AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments]
                                        WHERE report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports]
                                                            WHERE title = '", title, "'))", sep = "")
) %>%
  distinct(organization_id, .keep_all = TRUE)

#讀取教員資料表名稱
teacher_tablename <- dbGetQuery(edhr, 
                                paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                  WHERE title = '教員資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																						                                              WHERE title = '", department, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                                                      WHERE title = '", title, "'))))", sep = "")
) %>% as.character()


#教員資料表尚未建立的判斷
if(teacher_tablename == "character(0)"){
  stop("教員資料表尚未建立，故不執行資料檢核")
}else{
  
  

#讀取教員資料表
teacher <- dbGetQuery(edhr, 
                      paste("SELECT * FROM [rows].[dbo].[", teacher_tablename, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))

#欄位名稱更改為設定的欄位代號
col_names <- dbGetQuery(edhr, "SELECT id, name, title FROM [plat5_edhr].[dbo].[row_columns]")
col_names$id <- paste("C", col_names$id, sep = "")
for (i in 2 : dim(teacher)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(teacher)[i] <- col_names$name[grep(paste(colnames(teacher)[i], "$", sep = ""), col_names$id)]
}
#格式調整
teacher$gender <- formatC(teacher$gender, dig = 0, wid = 1, format = "f", flag = "0")
teacher$birthdate <- formatC(teacher$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
teacher$onbodat <- formatC(teacher$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
teacher$desedym <- formatC(teacher$desedym, dig = 0, wid = 4, format = "f", flag = "0")
teacher$beobdym <- formatC(teacher$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
teacher$organization_id <- formatC(teacher$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
teacher <- merge(x = teacher, y = list_agree, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

#讀取職員(工)資料表名稱
staff_tablename <- dbGetQuery(edhr, 
                              paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                   WHERE title = '職員(工)資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																							                                                 WHERE title = '", department, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                            WHERE title = '", title, "'))))", sep = "")
) %>% as.character()


#職員(工)資料表尚未建立的判斷
if(staff_tablename == "character(0)"){
  stop("職員(工)資料表尚未建立，故不執行資料檢核")
}else{
  
  

#讀取職員(工)資料表
staff <- dbGetQuery(edhr, 
                    paste("SELECT * FROM [rows].[dbo].[", staff_tablename, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))
#欄位名稱更改為設定的欄位代號
for (i in 2 : dim(staff)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(staff)[i] <- col_names$name[grep(paste(colnames(staff)[i], "$", sep = ""), col_names$id)]
}

#格式調整
staff$gender <- formatC(staff$gender, dig = 0, wid = 1, format = "f", flag = "0")
staff$birthdate <- formatC(staff$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
staff$onbodat <- formatC(staff$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
staff$desedym <- formatC(staff$desedym, dig = 0, wid = 4, format = "f", flag = "0")
staff$beobdym <- formatC(staff$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
staff$organization_id <- formatC(staff$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
staff <- merge(x = staff, y = list_agree, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

#讀取離退教職員(工)資料表名稱
retire_tablename <- dbGetQuery(edhr, 
                               paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                   WHERE title = '離退教職員(工)資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																							                                                 WHERE title = '", department, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                            WHERE title = '", title, "'))))", sep = "")
) %>% as.character()


#離退教職員(工)資料表尚未建立的判斷
if(retire_tablename == "character(0)"){
  stop("離退教職員(工)資料表尚未建立，故不執行資料檢核")
}else{
  
  

#讀取離退教職員(工)資料表
retire <- dbGetQuery(edhr, 
                     paste("SELECT * FROM [rows].[dbo].[", retire_tablename, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))
#欄位名稱更改為設定的欄位代號
for (i in 2 : dim(retire)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(retire)[i] <- col_names$name[grep(paste(colnames(retire)[i], "$", sep = ""), col_names$id)]
}

#格式調整
retire$organization_id <- formatC(retire$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
retire <- merge(x = retire, y = list_agree, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

data_teacher <- teacher
data_staff   <- staff
data_retire   <- retire
#data_load    <- read_excel(path, sheet = "教學資料表")
#data_courseA  <- read_excel(path, sheet = "授課資料表A.有課程代碼（23碼）")
#data_courseB  <- read_excel(path, sheet = "授課資料表B.無課程代碼（23碼）")

# 匯入上一期人事資料檔 -------------------------------------------------------------------
# 1111公立學校 教員資料表
#請輸入本次填報設定檔標題(字串需與標題完全相符，否則會找不到)
title_pre <- "111學年度上學期高級中等學校教育人力資源資料庫（公立學校人事）"

department_pre <- "人事室"

#讀取審核同意之學校名單
list_agree_pre <- dbGetQuery(edhr, 
                         paste("
SELECT DISTINCT b.id AS organization_id , 1 AS agree
FROM [plat5_edhr].[dbo].[teacher_fillers] a 
LEFT JOIN 
(SELECT a.reporter_id, c.id
FROM [plat5_edhr].[dbo].[teacher_fillers] a LEFT JOIN [plat5_edhr].[dbo].[teacher_reporters] b ON a.reporter_id = b.id
LEFT JOIN [plat5_edhr].[dbo].[organization_details] c ON b.organization_id = c.organization_id
) b ON a.reporter_id = b.reporter_id
WHERE a.agree = 1 AND department_id IN (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments]
                                        WHERE report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports]
                                                            WHERE title = '", title_pre, "'))", sep = "")
) %>%
  distinct(organization_id, .keep_all = TRUE)

#讀取教員資料表名稱
teacher_tablename_pre <- dbGetQuery(edhr, 
                                paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                  WHERE title = '教員資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																						                                              WHERE title = '", department_pre, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                                                      WHERE title = '", title_pre, "'))))", sep = "")
) %>% as.character()

#讀取教員資料表
teacher_pre <- dbGetQuery(edhr, 
                      paste("SELECT * FROM [rows].[dbo].[", teacher_tablename_pre, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))

#欄位名稱更改為設定的欄位代號
col_names_pre <- dbGetQuery(edhr, "SELECT id, name, title FROM [plat5_edhr].[dbo].[row_columns]")
col_names_pre$id <- paste("C", col_names_pre$id, sep = "")
for (i in 2 : dim(teacher_pre)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(teacher_pre)[i] <- col_names_pre$name[grep(paste(colnames(teacher_pre)[i], "$", sep = ""), col_names_pre$id)]
}
#格式調整
teacher_pre$gender <- formatC(teacher_pre$gender, dig = 0, wid = 1, format = "f", flag = "0")
teacher_pre$birthdate <- formatC(teacher_pre$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
teacher_pre$onbodat <- formatC(teacher_pre$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
teacher_pre$desedym <- formatC(teacher_pre$desedym, dig = 0, wid = 4, format = "f", flag = "0")
teacher_pre$beobdym <- formatC(teacher_pre$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
teacher_pre$organization_id <- formatC(teacher_pre$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
teacher_pre <- merge(x = teacher_pre, y = list_agree_pre, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

teacher_pre <- teacher_pre %>%
  mutate(dta_teacher = "教員資料表")

# 1111公立學校 職員(工)資料表
#讀取職員(工)資料表名稱
staff_tablename_pre <- dbGetQuery(edhr, 
                              paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                   WHERE title = '職員(工)資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																							                                                 WHERE title = '", department_pre, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                            WHERE title = '", title_pre, "'))))", sep = "")
) %>% as.character()

#讀取職員(工)資料表
staff_pre <- dbGetQuery(edhr, 
                    paste("SELECT * FROM [rows].[dbo].[", staff_tablename_pre, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))
#欄位名稱更改為設定的欄位代號
for (i in 2 : dim(staff_pre)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(staff_pre)[i] <- col_names_pre$name[grep(paste(colnames(staff_pre)[i], "$", sep = ""), col_names_pre$id)]
}

#格式調整
staff_pre$gender <- formatC(staff_pre$gender, dig = 0, wid = 1, format = "f", flag = "0")
staff_pre$birthdate <- formatC(staff_pre$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
staff_pre$onbodat <- formatC(staff_pre$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
staff_pre$desedym <- formatC(staff_pre$desedym, dig = 0, wid = 4, format = "f", flag = "0")
staff_pre$beobdym <- formatC(staff_pre$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
staff_pre$organization_id <- formatC(staff_pre$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
staff_pre <- merge(x = staff_pre, y = list_agree_pre, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

staff_pre <- staff_pre %>%
  mutate(dta_teacher = "職員(工)資料表")
#####合併#####
drev_person_pre_1111 <- bind_rows(teacher_pre, staff_pre) %>%
  rename(source = dta_teacher)


# 1112私立學校 教員資料表
#請輸入本次填報設定檔標題(字串需與標題完全相符，否則會找不到)
title_pre <- "111學年度下學期高級中等學校教育人力資源資料庫（私立學校人事）"

department_pre <- "人事室"

#讀取審核同意之學校名單
list_agree_pre <- dbGetQuery(edhr, 
                             paste("
SELECT DISTINCT b.id AS organization_id , 1 AS agree
FROM [plat5_edhr].[dbo].[teacher_fillers] a 
LEFT JOIN 
(SELECT a.reporter_id, c.id
FROM [plat5_edhr].[dbo].[teacher_fillers] a LEFT JOIN [plat5_edhr].[dbo].[teacher_reporters] b ON a.reporter_id = b.id
LEFT JOIN [plat5_edhr].[dbo].[organization_details] c ON b.organization_id = c.organization_id
) b ON a.reporter_id = b.reporter_id
WHERE a.agree = 1 AND department_id IN (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments]
                                        WHERE report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports]
                                                            WHERE title = '", title_pre, "'))", sep = "")
) %>%
  distinct(organization_id, .keep_all = TRUE)

#讀取教員資料表名稱
teacher_tablename_pre <- dbGetQuery(edhr, 
                                    paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                  WHERE title = '教員資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																						                                              WHERE title = '", department_pre, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                                                      WHERE title = '", title_pre, "'))))", sep = "")
) %>% as.character()

#讀取教員資料表
teacher_pre <- dbGetQuery(edhr, 
                          paste("SELECT * FROM [rows].[dbo].[", teacher_tablename_pre, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))

#欄位名稱更改為設定的欄位代號
col_names_pre <- dbGetQuery(edhr, "SELECT id, name, title FROM [plat5_edhr].[dbo].[row_columns]")
col_names_pre$id <- paste("C", col_names_pre$id, sep = "")
for (i in 2 : dim(teacher_pre)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(teacher_pre)[i] <- col_names_pre$name[grep(paste(colnames(teacher_pre)[i], "$", sep = ""), col_names_pre$id)]
}
#格式調整
teacher_pre$gender <- formatC(teacher_pre$gender, dig = 0, wid = 1, format = "f", flag = "0")
teacher_pre$birthdate <- formatC(teacher_pre$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
teacher_pre$onbodat <- formatC(teacher_pre$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
teacher_pre$desedym <- formatC(teacher_pre$desedym, dig = 0, wid = 4, format = "f", flag = "0")
teacher_pre$beobdym <- formatC(teacher_pre$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
teacher_pre$organization_id <- formatC(teacher_pre$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
teacher_pre <- merge(x = teacher_pre, y = list_agree_pre, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

teacher_pre <- teacher_pre %>%
  mutate(dta_teacher = "教員資料表")

# 1112私立學校 職員(工)資料表
#讀取職員(工)資料表名稱
staff_tablename_pre <- dbGetQuery(edhr, 
                                  paste("
SELECT [name] FROM [plat5_edhr].[dbo].[row_tables] 
	where sheet_id = (SELECT [id] FROM [plat5_edhr].[dbo].[row_sheets] 
						          where file_id = (SELECT field_component_id FROM [plat5_edhr].[dbo].[teacher_datasets] 
											                   WHERE title = '職員(工)資料表' AND department_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_departments] 
																							                                                 WHERE title = '", department_pre, "' AND  report_id = (SELECT id FROM [plat5_edhr].[dbo].[teacher_reports] 
																												                                                            WHERE title = '", title_pre, "'))))", sep = "")
) %>% as.character()

#讀取職員(工)資料表
staff_pre <- dbGetQuery(edhr, 
                        paste("SELECT * FROM [rows].[dbo].[", staff_tablename_pre, "] WHERE deleted_at IS NULL", sep = "")
) %>%
  subset(select = -c(id, created_at, deleted_at, updated_by, created_by, deleted_by))
#欄位名稱更改為設定的欄位代號
for (i in 2 : dim(staff_pre)[2]) #從2開始是因為第一的欄位是update_at
{
  colnames(staff_pre)[i] <- col_names_pre$name[grep(paste(colnames(staff_pre)[i], "$", sep = ""), col_names_pre$id)]
}

#格式調整
staff_pre$gender <- formatC(staff_pre$gender, dig = 0, wid = 1, format = "f", flag = "0")
staff_pre$birthdate <- formatC(staff_pre$birthdate, dig = 0, wid = 7, format = "f", flag = "0")
staff_pre$onbodat <- formatC(staff_pre$onbodat, dig = 0, wid = 7, format = "f", flag = "0")
staff_pre$desedym <- formatC(staff_pre$desedym, dig = 0, wid = 4, format = "f", flag = "0")
staff_pre$beobdym <- formatC(staff_pre$beobdym, dig = 0, wid = 4, format = "f", flag = "0")
staff_pre$organization_id <- formatC(staff_pre$organization_id, dig = 0, wid = 6, format = "f", flag = "0")

#只留下審核通過之名單
staff_pre <- merge(x = staff_pre, y = list_agree_pre, by = "organization_id", all.x = TRUE) %>%
  subset(agree == 1) %>%
  subset(select = -c(updated_at, agree))

staff_pre <- staff_pre %>%
  mutate(dta_teacher = "職員(工)資料表")
#####合併#####
drev_person_pre_1112 <- bind_rows(teacher_pre, staff_pre) %>%
  rename(source = dta_teacher)

#####111公+私合併#####
drev_person_pre <- bind_rows(drev_person_pre_1111, drev_person_pre_1112)

#檢查本次是否有新資料，若否，則不往下執行
data_teacher_check <- data_teacher %>%
  mutate(count = 1)
data_teacher_check <- aggregate(count ~ organization_id, data_teacher_check, sum)
data_teacher_check_save <- data_teacher_check #讀上次檔案之後再存
#讀上次的上傳資料結果
if(file.exists("./data_teacher_check_pre.xlsx")){
  data_teacher_check_pre <- readxl :: read_excel("./data_teacher_check_pre.xlsx")
  }else{
  }
#存本次的上傳資料結果，方便下次比對
openxlsx :: write.xlsx(data_teacher_check_save, file = "./data_teacher_check_pre.xlsx", rowNames = FALSE, overwrite = TRUE)
if(exists("data_teacher_check_pre")){
  data_teacher_check <- left_join(data_teacher_check, data_teacher_check_pre, by = "organization_id") %>%
    rename(count = count.x, count_pre = count.y) 
}else{
  }

data_staff_check <- data_staff %>%
  mutate(count = 1)
data_staff_check <- aggregate(count ~ organization_id, data_staff_check, sum)
data_staff_check_save <- data_staff_check #讀上次檔案之後再存
#讀上次的上傳資料結果
if(file.exists("./data_staff_check_pre.xlsx")){
  data_staff_check_pre <- readxl :: read_excel("./data_staff_check_pre.xlsx")
}else{
}
#存本次的上傳資料結果，方便下次比對
openxlsx :: write.xlsx(data_staff_check_save, file = "./data_staff_check_pre.xlsx", rowNames = FALSE, overwrite = TRUE)
if(exists("data_staff_check_pre")){
  data_staff_check <- left_join(data_staff_check, data_staff_check_pre, by = "organization_id") %>%
    rename(count = count.x, count_pre = count.y) 
}else{
}

data_retire_check <- data_retire %>%
  mutate(count = 1)
data_retire_check <- aggregate(count ~ organization_id, data_retire_check, sum)
data_retire_check_save <- data_retire_check #讀上次檔案之後再存
#讀上次的上傳資料結果
if(file.exists("./data_retire_check_pre.xlsx")){
  data_retire_check_pre <- readxl :: read_excel("./data_retire_check_pre.xlsx")
}else{
}
#存本次的上傳資料結果，方便下次比對
openxlsx :: write.xlsx(data_retire_check_save, file = "./data_retire_check_pre.xlsx", rowNames = FALSE, overwrite = TRUE)
if(exists("data_retire_check_pre")){
  data_retire_check <- left_join(data_retire_check, data_retire_check_pre, by = "organization_id") %>%
    rename(count = count.x, count_pre = count.y) 
}else{
}

#如果count及count_pre有值且count = count_pre代表沒有新資料，如果count有值且count_pre為NA則有新資料

  #count_pre為NA的處理
  data_teacher_check$count_pre[is.na(data_teacher_check$count_pre)] <- 0
  data_staff_check$count_pre[is.na(data_staff_check$count_pre)] <- 0
  data_retire_check$count_pre[is.na(data_retire_check$count_pre)] <- 0
  
if(all(data_teacher_check$count == data_teacher_check$count_pre) & 
   all(data_staff_check$count == data_staff_check$count_pre) & 
   all(data_retire_check$count == data_retire_check$count_pre) & 
   length(data_teacher_check$count_pre) > 0){
  stop("本次無新資料，故不執行資料檢核")
}else{
# 合併人事資料表 ----------------------------------------------------------------
data_teacher <- data_teacher %>%
  mutate(source = 1)

data_staff <- data_staff %>%
  mutate(source = 2)

drev_person <- bind_rows(data_teacher, data_staff)

drev_person$source  <- factor(drev_person$source, levels = c(1, 2), labels = c("教員資料表", "職員(工)資料表"))
#這行在更改source的1和2為教員資料表及職員工資料表，levels是排序依據.

# 統計處高級中等學校科別資料 -----------------------------------------------------------
filename <- "./111_base2_revise.xlsx"

# 讀取檔案
data_schtype <- read_excel(filename)

data_schtype <- c("學校代碼", "學校名稱", "學程(等級)別", "學程(等級)名稱", "日夜別", "日夜別名稱", "群別代碼", "群別名稱", "科系代碼", "科系名稱", "班級數", "學生數") %>%
  data_schtype[, .]
# 改變變項名稱與形態
data_schtype <-plyr:: rename(data_schtype, c(   "學校代碼"       = "organization_id"
                                                , "學校名稱"       = "edu_name"
                                                , "學程(等級)別"   = "type_code"
                                                , "學程(等級)名稱" = "type_name"
                                                , "日夜別"         = "dn_code"
                                                , "日夜別名稱"     = "dn_name"
                                                , "群別代碼"       = "dep1_code"
                                                , "群別名稱"       = "dep1_name"
                                                , "科系代碼"       = "depcode"
                                                , "科系名稱"       = "dep2_name"
                                                , "班級數"         = "nclass"
                                                , "學生數"         = "nstudent"))
data_schtype$nclass[data_schtype$nclass == "-"]     <- NA
data_schtype$nstudent[data_schtype$nstudent == "-"] <- NA
data_schtype$nclass   <- as.numeric(data_schtype$nclass)
data_schtype$nstudent <- as.numeric(data_schtype$nstudent)

data_schtype$organization_id <- recode_factor(data_schtype$organization_id,
                                       "140222" = "140401"
                                       , "400144" = "400419")
data_schtype$try1 <- NA
data_schtype$try1 <- 1
# 主管機關
data_schtype$authority <- NA
data_schtype$authority[substr(data_schtype$organization_id, 3, 3) == "0"] <- "國立"
data_schtype$authority[substr(data_schtype$organization_id, 3, 3) == "1"] <- "私立"
data_schtype$authority[substr(data_schtype$organization_id, 3, 3) == "3" | substr(data_schtype$organization_id, 3, 3) == "4"] <- "縣市立"

data_schtype$authority[       data_schtype$authority == "國立" & (data_schtype$organization_id == "140401" | data_schtype$organization_id == "400419")]                                     <-  "技職司管轄國立"    
data_schtype$authority[       data_schtype$authority == "國立" & (data_schtype$organization_id == "110328" | data_schtype$organization_id == "180301" | data_schtype$organization_id == "060323")] <-  "國教署與科技部共管"                         


data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 1]  <- "新北市市立"
data_schtype$authority[       data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 1]  <- "新北市私立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 2]  <- "宜蘭縣縣立"
data_schtype$authority[       data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 3]  <- "桃園市私立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 3]  <- "桃園市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 4]  <- "新竹縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 5]  <- "苗栗縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 6]  <- "臺中市市立"
data_schtype$authority[       data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 6]  <- "臺中市私立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 7]  <- "彰化縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 8]  <- "南投縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 9]  <- "雲林縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 10] <- "嘉義縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 11] <- "臺南市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 12] <- "高雄市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 13] <- "屏東縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 14] <- "臺東縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 15] <- "花蓮縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 16] <- "澎湖縣縣立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 17] <- "基隆市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 18] <- "新竹市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 19] <- "臺中市市立"
data_schtype$authority[       data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 19] <- "臺中市私立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 20] <- "嘉義市市立"
data_schtype$authority[       data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 21] <- "臺南市市立"

for (x in 30:42){
  data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == x]  <- "臺北市市立"
  data_schtype$authority[data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == x]  <- "臺北市私立"
}

for (x in 50:61){
  data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == x]  <- "高雄市市立"
  data_schtype$authority[data_schtype$authority ==   "私立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == x]  <- "高雄市私立"
}
data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 64] <- "高雄市市立"
data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 66] <- "臺中市市立"
data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 67] <- "臺南市市立"                        
data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 71] <- "金門縣縣立"
data_schtype$authority[data_schtype$authority == "縣市立" & as.numeric(substr(data_schtype$organization_id, 1, 2)) == 72] <- "連江縣縣立"          
data_schtype$authority[data_schtype$authority == "國立"]                                                           <- "國教署管轄國立" 
data_schtype$authority[data_schtype$authority == "私立"]                                                           <- "國教署管轄私立"


# type_code
data_schtype$type_code <- recode_factor(data_schtype$type_code,
                                        "A" = "H"
                                        ,"B" = "V"
                                        ,"O" = "M")
data_schtype$type_code <- factor(data_schtype$type_code, levels = c("C", "E", "F", "H", "V", "M", "J", "U"))
data_schtype$type_code[data_schtype$dn_code == "D" & data_schtype$type_code == "U"] <- "E"
data_schtype$type_code[data_schtype$dn_code == "N" & data_schtype$type_code == "U"] <- "F"

# 各校班級的開課單位
data_schtype_wide <- data_schtype %>%
  mutate(schtype = paste("type", type_code, sep = "")) %>%
  spread(key = schtype, value = nstudent)

data_schtype_wide <- data_schtype_wide %>%
  group_by(organization_id) %>%
  mutate(typeC = sum(typeC, na.rm = TRUE)) %>%
  group_by(organization_id) %>%
  mutate(typeH = sum(typeH, na.rm = TRUE)) %>%              
  group_by(organization_id) %>%
  mutate(typeJ = sum(typeJ, na.rm = TRUE)) %>%
  group_by(organization_id) %>%
  mutate(typeV = sum(typeV, na.rm = TRUE)) %>%
  group_by(organization_id) %>%
  mutate(typeM = sum(typeM, na.rm = TRUE)) %>%
  group_by(organization_id) %>%
  mutate(typeF = sum(typeF, na.rm = TRUE)) %>%
  group_by(organization_id) %>%
  mutate(typeE = sum(typeE, na.rm = TRUE)) 

# 國際部與雙語部的名單會逐年變動。


temp <- data_schtype %>%  
  filter(dep1_code == "11", dep2_name == "雙語部") %>%
  distinct(organization_id) %>%
  `[[`(1) %>%
  as.character()

data_schtype_wide$typeD <- 0
for (x in temp){
  data_schtype_wide <- data_schtype_wide %>% 
    mutate(typeD = if_else((organization_id == x | typeD == 1), 1 ,0)) 
}

data_schtype_wide <- data_schtype_wide %>%
  mutate(typeH = if_else(as.numeric(typeH) > 1, 1, 0, missing = NULL),
         typeJ = if_else(as.numeric(typeJ) > 1, 1, 0, missing = NULL),
         typeV = if_else(as.numeric(typeV) > 1, 1, 0, missing = NULL),
         typeC = if_else(as.numeric(typeC) > 1, 1, 0, missing = NULL),
         typeM = if_else(as.numeric(typeM) > 1, 1, 0, missing = NULL),
         typeF = if_else(as.numeric(typeF) > 1, 1, 0, missing = NULL),
         typeE = if_else(as.numeric(typeE) > 1, 1, 0, missing = NULL),
         typeD = if_else(as.numeric(typeD) > 1, 1, 0, missing = 0))

# 更改人事資料表的學校名稱（若學校名單異動，哪幾間學校名稱需簡寫亦要檢視） -------------------------------------------------------------------
organization <- dbGetQuery(edhr, "SELECT a.id as organization_id, b.name as edu_name2
  FROM
  (SELECT id, max(year) as year
  FROM [plat5_edhr].[dbo].[organization_details]
  group by id) a LEFT JOIN (SELECT id, year, name
							FROM [plat5_edhr].[dbo].[organization_details]) b ON a.id = b.id AND a.year = b.year
  where (substring(a.id, 4, 1) = '1' OR substring(a.id, 4, 1) = '2' OR substring(a.id, 4, 1) = '3' OR substring(a.id, 4, 1) = '4' OR substring(a.id, 4, 1) = 'B' OR substring(a.id, 4, 1) = 'C' OR substring(a.id, 4, 1) = 'F' OR substring(a.id, 4, 1) = 'G') and len(a.id) = 6")

drev_person <- drev_person %>%
  left_join(organization, by = "organization_id")

# 人事資料表合併學校科別資訊 ----------------------------------------------------------------
drev_person_1 <- data_schtype_wide %>%
  select(organization_id, typeC, typeD, typeM, typeH, typeV, typeJ, typeE, typeF) %>%
  distinct(organization_id, typeC, typeD, typeM, typeH, typeV, typeJ, typeE, typeF) %>%
  merge(x = drev_person, by = "organization_id", all.x = TRUE) %>%
  distinct()

# 人事資料表資料格式修正 ------------------------------------------------------------------

# 若比對目標為xxx，使用grep函數 
  # grep函數用法：grep("xxx", data名稱$欄位名稱)
  # grep函數中第一個參數：  
    # xxx：包含xxx的字串都會搜尋出來
    # ^xxx：搜尋開頭為xxx的字串
    # xxx$：搜尋結尾為xxx的字串
    # ^xxx$：搜尋完全符合xxx的字串

#調整英文字母大小寫
temp <- c("idnumber", "implcls", "skillteacher", "counselor", "speteacher", "joiteacher", "expecter", "study", "ddegreen1", "ddegreeu1", "ddegreeg1", "ddegreen2", "ddegreeu2", "ddegreeg2", "mdegreen1", "mdegreeu1", "mdegreeg1", "mdegreen2", "mdegreeu2", "mdegreeg2", "bdegreen1", "bdegreeu1", "bdegreeg1", "bdegreen2", "bdegreeu2", "bdegreeg2", "adegreen1", "adegreeu1", "adegreeg1", "adegreen2", "adegreeu2", "adegreeg2", "leave", "admintitle", "adminunit", "admintitle1", "adminunit1", "admintitle2", "adminunit2", "admintitle3", "adminunit3")
for (x in temp) {
  drev_person_1[[x]] <- drev_person_1[[x]] %>% toupper()
}

#刪除空格的方程式
trim <- function (x){
  gsub("\\s+", "", x)
}

#刪除空格 "\\s+"
#刪除字串前面或者字串後面的空格 "^\\s+|\\s+$"
temp <- names(drev_person)
temp1 <- c("name","ddegreen1", "ddegreeu1", "ddegreeg1", "ddegreen2", "ddegreeu2", "ddegreeg2", "mdegreen1", "mdegreeu1", "mdegreeg1", "mdegreen2", "mdegreeu2", "mdegreeg2", "bdegreen1", "bdegreeu1", "bdegreeg1", "bdegreen2", "bdegreeu2", "bdegreeg2", "adegreen1", "adegreeu1", "adegreeg1", "adegreen2", "adegreeu2", "adegreeg2", "source", "edu_name2")
for (i in temp1){
  temp <- temp[-which(temp == i)]
}
for (x in temp) {
  drev_person_1[[x]] <- trim(drev_person_1[[x]])
}

#職務名稱、服務單位 欄位名稱更名 方便分析
names(drev_person_1)[which(names(drev_person_1) == "admintitle")] <- "admintitle0"
names(drev_person_1)[which(names(drev_person_1) == "adminunit")] <- "adminunit0"

temp <- c("admintitle0", "adminunit0", "admintitle1", "adminunit1", "admintitle2", "adminunit2", "admintitle3", "adminunit3")
for (x in temp){
  drev_person_1[[x]][grep("^祕書$", drev_person_1[[x]])] <- "秘書"
  drev_person_1[[x]][grep("^圖書管主任$", drev_person_1[[x]])] <- "圖書館主任"
}	

#教員資料表無專任行政職欄位 調整成N 方便分析
temp <- c("admintitle0", "adminunit0")
for (x in temp){
  drev_person_1[[x]][is.na(drev_person_1[[x]])] <- "N"
}	

#國籍別、畢業學校國別
temp <- c("nation", "ddegreen1", "ddegreen2", "mdegreen1", "mdegreen2", "bdegreen1", "bdegreen2", "adegreen1", "adegreen2")
for (x in temp){
  drev_person_1[[x]][grep("^本國籍$", drev_person_1[[x]])] <- "本國"
  drev_person_1[[x]][grep("^澳洲$", drev_person_1[[x]])] <- "澳大利亞"
}	

#亂碼
drev_person_1[["mdegreeu1"]][grep("^國立台灣藝術?學$", drev_person_1[["mdegreeu1"]])] <- "國立台灣藝術大學"
drev_person_1[["mdegreeu1"]][grep("^私立中華科技?學$", drev_person_1[["mdegreeu1"]])] <- "私立中華科技大學"

drev_person_1[["mdegreeg1"]][grep("^?物科技系$", drev_person_1[["mdegreeg1"]])] <- "生物科技系"

drev_person_1[["bdegreeu1"]][grep("^國立台北科技?學$", drev_person_1[["bdegreeu1"]])] <- "國立台北科技大學"
drev_person_1[["bdegreeu1"]][grep("^?雄餐旅?學$", drev_person_1[["bdegreeu1"]])] <- "高雄餐旅大學"
drev_person_1[["bdegreeu1"]][grep("^銘傳?學$", drev_person_1[["bdegreeu1"]])] <- "銘傳大學"
drev_person_1[["bdegreeu1"]][grep("^德明財經科技?學$", drev_person_1[["bdegreeu1"]])] <- "德明財經科技大學"
drev_person_1[["bdegreeu1"]][grep("^國立台灣藝術?學$", drev_person_1[["bdegreeu1"]])] <- "國立台灣藝術大學"
drev_person_1[["bdegreeu1"]][grep("^吳鳳科技?學$", drev_person_1[["bdegreeu1"]])] <- "吳鳳科技大學"
drev_person_1[["bdegreeu1"]][grep("^弘光科技?學$", drev_person_1[["bdegreeu1"]])] <- "弘光科技大學"

drev_person_1[["bdegreeg1"]][grep("^?輛?程系$", drev_person_1[["bdegreeg1"]])] <- "車輛工程系"
drev_person_1[["bdegreeg1"]][grep("^?餐廚藝系$", drev_person_1[["bdegreeg1"]])] <- "西餐廚藝系"
drev_person_1[["bdegreeg1"]][grep("^化妝品應?管理系$", drev_person_1[["bdegreeg1"]])] <- "化妝品應用管理系"



#將gender由字串轉成數字
drev_person_1 <- drev_person_1 %>% 
  transform(gender = as.numeric(gender))

# 人事資料表與離退教職員(工)資料表合併 (inner join) -----------------------------------------------------------
drev_P_retire <- merge(x = drev_person_1, y = data_retire, by = c("organization_id", "idnumber"))

# 前一期人事資料表與離退教職員(工)資料表合併 (inner join) -----------------------------------------------------------
drev_P_retire_pre_inner <- merge(x = drev_person_pre, y = data_retire, by = c("organization_id", "idnumber"))
# 前一期人事資料表與離退教職員(工)資料表合併 (right join) -----------------------------------------------------------
drev_person_pre_1 <- drev_person_pre %>%
  mutate(pre = 1)
drev_P_retire_pre_right <- merge(x = drev_person_pre_1, y = data_retire, by = c("organization_id", "idnumber"), all.y = TRUE)

#學校名稱 (本次已上傳學校)
edu_name2 <- data.frame(
  "organization_id" = drev_person$organization_id, 
  "edu_name2" = drev_person$edu_name2
) %>%
  distinct(organization_id, .keep_all = TRUE)
#本期人事資料表與前一期人事資料表合併 -----------------------------------------------------------
drev_person_2 <- drev_person %>%
  mutate(now = 1)
drev_P_retire_merge_pre <- merge(x = drev_person_2, y = drev_person_pre_1, by = c("organization_id", "idnumber"), all.x = TRUE, all.y = TRUE)
#只留已上傳學校
drev_P_retire_merge_pre <- merge(x = drev_P_retire_merge_pre, y = edu_name2, by = c("organization_id"))
#再與本次離退表合併
data_retire_1 <- data_retire %>%
  mutate(retire = 1)
drev_P_retire_merge_pre <- merge(x = drev_P_retire_merge_pre, y = data_retire_1, by = c("organization_id", "idnumber"), all.x = TRUE, all.y = TRUE)

# # 人事資料表與教學資料表合併 -----------------------------------------------------------
# drev_P_load <- merge(x = drev_person_1, y = data_load, by = c("organization_id", "idnumber"), all.x = TRUE, all.y = TRUE)
# 
# # 教學資料表資料格式修正 ------------------------------------------------------------------
# temp <- c("tutor", "mitleader", "classleader", "ccounselor", "adminteacher", "specurr")
# for (x in temp) {
#   drev_P_load[[x]] <- drev_P_load[[x]] %>% toupper()
# }
# 
# temp <- c("mainsub", "tutor", "mitleader", "classleader", "ccounselor", "adminteacher", "specurr")
# for (x in temp) {
#   drev_P_load[[x]] <- trim(drev_P_load[[x]])
# }
# 
# #主要任教科別
# drev_P_load[["mainsub"]][grep("^汽事科$", drev_P_load[["mainsub"]])] <- "汽車科"
# 
# #所擔任召集人之學科名稱
# drev_P_load[["mitleader"]][grep("^汽事科$", drev_P_load[["mitleader"]])] <- "汽車科"
# 
# temp <- c("basic", "cut", "othertime", "othertimeb")
# for (x in temp) {
#   drev_P_load[[x]][grep("^NA$", drev_P_load[[x]])] <- NA
# }
# 
# 
# # 主要任教科目 ------------------------------------------------------------------
# drev_P_load$depcode_p <- case_when(
#   drev_P_load$mainsub == "機械群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "101",
#   drev_P_load$mainsub == "動力機械群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "102",
#   drev_P_load$mainsub == "化工群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "103",
#   drev_P_load$mainsub == "電機與電子群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "104",
#   drev_P_load$mainsub == "土木與建築群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "105",
#   drev_P_load$mainsub == "商業與管理群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "106",
#   drev_P_load$mainsub == "外語群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "107",
#   drev_P_load$mainsub == "設計群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "108",
#   drev_P_load$mainsub == "藝術群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "109",
#   drev_P_load$mainsub == "農業群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "110",
#   drev_P_load$mainsub == "食品群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "111",
#   drev_P_load$mainsub == "餐旅群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "112",
#   drev_P_load$mainsub == "家政群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "113",
#   drev_P_load$mainsub == "海事群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "114",
#   drev_P_load$mainsub == "水產群" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "115",
#   drev_P_load$mainsub == "農場經營科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "201",
#   drev_P_load$mainsub == "園藝科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "202",
#   drev_P_load$mainsub == "森林科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "204",
#   drev_P_load$mainsub == "農業機械科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "205",
#   drev_P_load$mainsub == "食品加工科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "206",
#   drev_P_load$mainsub == "野生動物保育科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "214",
#   drev_P_load$mainsub == "農產行銷科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "215",
#   drev_P_load$mainsub == "造園科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "216",
#   drev_P_load$mainsub == "畜產保健科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "217",
#   drev_P_load$mainsub == "機械科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "301",
#   drev_P_load$mainsub == "鑄造科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "302",
#   drev_P_load$mainsub == "汽車科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "303",
#   drev_P_load$mainsub == "板金科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "304",
#   drev_P_load$mainsub == "資訊科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "305",
#   drev_P_load$mainsub == "電子科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "306",
#   drev_P_load$mainsub == "控制科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "307",
#   drev_P_load$mainsub == "電機科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "308",
#   drev_P_load$mainsub == "冷凍空調科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "309",
#   drev_P_load$mainsub == "建築科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "311",
#   drev_P_load$mainsub == "家具木工科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "312",
#   drev_P_load$mainsub == "化工科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "315",
#   drev_P_load$mainsub == "美工科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "316",
#   drev_P_load$mainsub == "美術工藝科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "318",
#   drev_P_load$mainsub == "紡織科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "319",
#   drev_P_load$mainsub == "電機空調科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "321",
#   drev_P_load$mainsub == "機械木模科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "332",
#   drev_P_load$mainsub == "配管科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "337",
#   drev_P_load$mainsub == "模具科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "338",
#   drev_P_load$mainsub == "染整科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "352",
#   drev_P_load$mainsub == "機電科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "360",
#   drev_P_load$mainsub == "陶瓷工程科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "361",
#   drev_P_load$mainsub == "製圖科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "363",
#   drev_P_load$mainsub == "重機科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "364",
#   drev_P_load$mainsub == "土木科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "365",
#   drev_P_load$mainsub == "室內空間設計科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "366",
#   drev_P_load$mainsub == "環境檢驗科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "367",
#   drev_P_load$mainsub == "生物產業機電科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "372",
#   drev_P_load$mainsub == "圖文傳播科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "373",
#   drev_P_load$mainsub == "電腦機械製圖科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "374",
#   drev_P_load$mainsub == "軌道車輛科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "380",
#   drev_P_load$mainsub == "飛機修護科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "381",
#   drev_P_load$mainsub == "飛修科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "381",
#   drev_P_load$mainsub == "航空電子科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "384",
#   drev_P_load$mainsub == "動力機械科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "392",
#   drev_P_load$mainsub == "金屬工藝科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "394",
#   drev_P_load$mainsub == "消防工程科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "397",
#   drev_P_load$mainsub == "空間測繪科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "398",
#   drev_P_load$mainsub == "家具設計科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "399",
#   drev_P_load$mainsub == "商業經營科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "401",
#   drev_P_load$mainsub == "商經科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "401",
#   drev_P_load$mainsub == "國際貿易科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "402",
#   drev_P_load$mainsub == "國貿科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "402",
#   drev_P_load$mainsub == "會計事務科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "403",
#   drev_P_load$mainsub == "資料處理科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "404",
#   drev_P_load$mainsub == "資處科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "404",
#   drev_P_load$mainsub == "廣告設計科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "406",
#   drev_P_load$mainsub == "觀光事業科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "407",
#   drev_P_load$mainsub == "餐飲管理科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "408",
#   drev_P_load$mainsub == "不動產事務科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "418",
#   drev_P_load$mainsub == "電子商務科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "425",
#   drev_P_load$mainsub == "流通管理科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "426",
#   drev_P_load$mainsub == "多媒體設計科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "430",
#   drev_P_load$mainsub == "多媒體應用科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "431",
#   drev_P_load$mainsub == "應用英語科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "433",
#   drev_P_load$mainsub == "應用日語科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "434",
#   drev_P_load$mainsub == "家政科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "501",
#   drev_P_load$mainsub == "服裝科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "502",
#   drev_P_load$mainsub == "幼兒保育科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "503",
#   drev_P_load$mainsub == "美容科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "504",
#   drev_P_load$mainsub == "食品科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "505",
#   drev_P_load$mainsub == "室內設計科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "512",
#   drev_P_load$mainsub == "時尚模特兒科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "513",
#   drev_P_load$mainsub == "流行服飾科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "515",
#   drev_P_load$mainsub == "時尚造型科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "516",
#   drev_P_load$mainsub == "烘焙科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "517",
#   drev_P_load$mainsub == "漁業科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "701",
#   drev_P_load$mainsub == "輪機科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "702",
#   drev_P_load$mainsub == "電子通信科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "703",
#   drev_P_load$mainsub == "水產養殖科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "705",
#   drev_P_load$mainsub == "水產經營科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "706",
#   drev_P_load$mainsub == "航海科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "708",
#   drev_P_load$mainsub == "航運管理科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "717",
#   drev_P_load$mainsub == "水產食品科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "718",
#   drev_P_load$mainsub == "戲劇科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "801",
#   drev_P_load$mainsub == "音樂科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "802",
#   drev_P_load$mainsub == "舞蹈科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "803",
#   drev_P_load$mainsub == "美術科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "804",
#   drev_P_load$mainsub == "影劇科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "806",
#   drev_P_load$mainsub == "西樂科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "807",
#   drev_P_load$mainsub == "國樂科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "808",
#   drev_P_load$mainsub == "劇場藝術科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "813",
#   drev_P_load$mainsub == "電影電視科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "816",
#   drev_P_load$mainsub == "表演藝術科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "817",
#   drev_P_load$mainsub == "多媒體動畫科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "820",
#   drev_P_load$mainsub == "時尚工藝科" & (drev_P_load$typeM == 1 | drev_P_load$typeV == 1 | drev_P_load$typeC == 1) ~ "822",
#   (drev_P_load$mainsub == "資訊應用學程" | drev_P_load$mainsub == "資訊應用科") & drev_P_load$typeM == 1 ~ "F01",
#   drev_P_load$mainsub == "國語文" | drev_P_load$mainsub == "國文" | drev_P_load$mainsub == "國文科" ~ "01",
#   drev_P_load$mainsub == "英語文" | drev_P_load$mainsub == "英語" | drev_P_load$mainsub == "英文" | drev_P_load$mainsub == "英文科" ~ "02",
#   drev_P_load$mainsub == "數學" | drev_P_load$mainsub == "數學科" ~ "03",
#   drev_P_load$mainsub == "歷史" | drev_P_load$mainsub == "歷史科" ~ "09",
#   drev_P_load$mainsub == "地理" | drev_P_load$mainsub == "地理科" ~ "0A",
#   drev_P_load$mainsub == "公民與社會" | drev_P_load$mainsub == "公民與社會科" | drev_P_load$mainsub == "公民" | drev_P_load$mainsub == "公民科" ~ "0B",
#   drev_P_load$mainsub == "物理" | drev_P_load$mainsub == "物理科" ~ "0C",
#   drev_P_load$mainsub == "化學" | drev_P_load$mainsub == "化學科" ~ "0D",
#   drev_P_load$mainsub == "生物" | drev_P_load$mainsub == "生物科" ~ "0E",
#   grepl("^地球科學", drev_P_load$mainsub) | drev_P_load$mainsub == "地科" | drev_P_load$mainsub == "地科科" ~ "0F",
#   drev_P_load$mainsub == "音樂" | (drev_P_load$mainsub == "音樂科" & (drev_P_load$typeM == 0 | drev_P_load$typeV == 0 | drev_P_load$typeC == 0)) ~ "0U",
#   drev_P_load$mainsub == "美術" | (drev_P_load$mainsub == "美術科" & (drev_P_load$typeM == 0 | drev_P_load$typeV == 0 | drev_P_load$typeC == 0)) ~ "0V",
#   drev_P_load$mainsub == "藝術生活" | drev_P_load$mainsub == "藝術生活科" | drev_P_load$mainsub == "藝術科" | drev_P_load$mainsub == "視覺應用" | drev_P_load$mainsub == "音樂應用" | drev_P_load$mainsub == "表演藝術" ~ "0W",
#   drev_P_load$mainsub == "生命教育" ~ "0X",
#   drev_P_load$mainsub == "生涯規劃" ~ "0Y",
#   drev_P_load$mainsub == "家政" | (drev_P_load$mainsub == "家政科" & (drev_P_load$typeM == 0 | drev_P_load$typeV == 0 | drev_P_load$typeC == 0)) ~ "0Z",
#   drev_P_load$mainsub == "法律與生活" | drev_P_load$mainsub == "法律與生活科" ~ "10",
#   drev_P_load$mainsub == "環境科學概論" ~ "11",
#   drev_P_load$mainsub == "生活科技" | drev_P_load$mainsub == "生活科技科" | drev_P_load$mainsub == "生科科" ~ "12",
#   drev_P_load$mainsub == "資訊科技" | (drev_P_load$mainsub == "資訊科" & (drev_P_load$typeM == 0 | drev_P_load$typeV == 0 | drev_P_load$typeC == 0)) ~ "13",
#   grepl("健康與護理", drev_P_load$mainsub) | grepl("健康護理", drev_P_load$mainsub) | drev_P_load$mainsub == "健護" | drev_P_load$mainsub == "健護科" | drev_P_load$mainsub == "護理科" ~ "14",
#   drev_P_load$mainsub == "體育" | drev_P_load$mainsub == "體育科" ~ "15",
#   grepl("全民國防", drev_P_load$mainsub) | drev_P_load$mainsub == "軍訓科" | drev_P_load$mainsub == "軍訓" | drev_P_load$mainsub == "國防教育科" ~ "16",
#   grepl("特殊教育", drev_P_load$mainsub) | drev_P_load$mainsub == "特教科" | drev_P_load$mainsub == "特教" | drev_P_load$mainsub == "特殊需求領域(身心障礙)" | drev_P_load$mainsub == "身心障礙" | drev_P_load$mainsub == "資賦優異" ~ "929"
# )

# 需要每個學期重新調整的項目 -----------------------------------------------------------

### flag_person
# flag2、flag3；spe2、spe6。
# 以上檢查項目依最新的學校名單、群科開設狀況而定。相關資訊可上統計處查詢高級中等學校科別資料。
# flag6需檢查各表姓名是否為純中文或純英文，或者是否夾雜其他運算字元、特殊符號。
# flag8需檢查持外來人口統一證號的教職員(工)是否有填其國籍別，又其國籍別是否足以辨認。
# flag9需檢查最高學歷畢業學校國別（一）(schooln1)所填之國籍別是否足以辨認。
# flag_person <- drev_person_1 %>%
#   mutate(err_flag_2 = if_else((organization_id == "011315" | organization_id == "013430" | organization_id == "110409" | organization_id == "193404" | organization_id == "381305" | organization_id == "533402"), 1, 0),
#          err_flag_3 = if_else(organization_id == "110302", 1, 0),
#          err_spe_2  = if_else(typeD == 1 & empunit != "雙語部" & source == "教員資料表", 1, 0),
#          err_spe_6  = if_else(typeJ == 1, 1, 0),
#          err_flag_6 = if_else(name == "吳淑貞-", 1, 0),
#          err_flag_8 = if_else(nation == "外籍", 1, 0),
#          err_flag_9 = 0)
# 目前僅限於人事資料表範圍內的檢查項目暫無需檢查是否擔任「科主任」、「學程主任」，
# 因此在備分的檔案(flag_person)先把這兩個職稱拿掉。若往後有此需要，請再另行處理。
# temp <- seq(from = 18, to = 25 , by = 2)
# for (x in temp){
#   flag_person[grep("$科主任", flag_person[x]), ] <- flag_person %>%
#     slice(grep("$科主任", flag_person[x])) %>%
#     mutate(err_flag_2, recode(err_flag_2, "1 = 0"))
#   
#   flag_person[grep("$學程主任", flag_person[x]), ] <- flag_person %>%
#     slice(grep("$學程主任", flag_person[x])) %>%
#     mutate(err_flag_3, recode(err_flag_3, "1 = 0"))
# }



# flag1: 學校（副）校長、一級單位主管名單的完整度 -------------------------------------------------------------------
# temp <- c("admintitle0", "admintitle1", "admintitle2", "admintitle3")
# for (x in temp){
#   flag_person[[x]] <- drev_person_1[[x]] %>%
#     gsub(pattern = "科主任", replacement = "") %>%
#     gsub(pattern = "主任教官", replacement = "") %>%
#     gsub(pattern = "學程主任", replacement = "")
# }

flag_person <- drev_person_1 %>%
  mutate(admin1 = 0, admin2 = 0, admin3 = 0, admin4 = 0, admin5 = 0, admin6 = 0, admin7 = 0, admin8 = 0, admin9 = 0)

flag_person$admin1 <- case_when(
  flag_person$sertype == "校長" | flag_person$admintitle1 == "校長" | flag_person$admintitle1 == "校長1" | flag_person$admintitle2 == "校長1" | flag_person$admintitle3 == "校長1" | grepl("/校長1", flag_person$admintitle1) | grepl("校長1/", flag_person$admintitle1) | grepl("/校長1", flag_person$admintitle2) | grepl("校長1/", flag_person$admintitle2) | grepl("/校長1", flag_person$admintitle3) | grepl("校長1/", flag_person$admintitle3) ~ 1,
  TRUE ~ flag_person$admin1
)

flag_person$admin7 <- case_when(
  flag_person$typeV == 0 ~ 1,
  TRUE ~ flag_person$admin7
)

temp <- c("0", "1", "2", "3")
for (x in temp){
  flag_person$admin2 <- case_when(
     grepl("教務", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin2
  )
}     
for (x in temp){
  flag_person$admin3 <- case_when(
    (grepl("學務", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("學生事務", flag_person[[paste("adminunit", x, sep = "")]]))                                                                & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin3
  )
}                
for (x in temp){
  flag_person$admin4 <- case_when(
     grepl("總務", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin4
  )
}                
for (x in temp){
  flag_person$admin5 <- case_when(
     grepl("輔導", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任輔導教師$", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin5
  )
}                
for (x in temp){
  flag_person$admin6 <- case_when(
     (grepl("圖書", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("圖資", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("圖書資訊", flag_person[[paste("adminunit", x, sep = "")]])) & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^館長$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin6
  )
}  
for (x in temp){
  flag_person$admin7 <- case_when(
     grepl("實習", flag_person[[paste("adminunit", x, sep = "")]]) & flag_person$typeV == 1                                                                                                            & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin7
  )
}     
for (x in temp){  
  flag_person$admin8 <- case_when(
    grepl("人事", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                      & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^人事管理員$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin8
  )
}                
for (x in temp){
  flag_person$admin9 <- case_when(
    (grepl("會計", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("主計", flag_person[[paste("adminunit", x, sep = "")]]))                                                                    & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^主計員$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("^主計員$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$admin9
  )
}  

#NOTE:實習處主任設置條件為：1.只有專業群科 or 2.只有專業群科和綜合高中 or 3.只有專業群科和實用技能學程
#NOTE:2021/04/20討論：只要有專業群科的學校，都需檢查有無實習處，其他類別不管

flag1 <- flag_person %>%
  group_by(organization_id) %>%
  mutate(admin1 = max(admin1),
         admin2 = max(admin2),
         admin3 = max(admin3),
         admin4 = max(admin4),
         admin5 = max(admin5),
         admin6 = max(admin6),
         admin7 = max(admin7),
         admin8 = max(admin8),
         admin9 = max(admin9)) %>%
  mutate(admin1_txt = if_else(admin1 == 0, "校長", ""),
         admin2_txt = if_else(admin2 == 0, "教務處主管", ""),
         admin3_txt = if_else(admin3 == 0, "學務處主管", ""),
         admin4_txt = if_else(admin4 == 0, "總務處主管", ""),
         admin5_txt = if_else(admin5 == 0, "輔導室主管", ""),
         admin6_txt = if_else(admin6 == 0, "圖書館主管", ""),
         admin7_txt = if_else(admin7 == 0, "實習處主管", ""),
         admin8_txt = if_else(admin8 == 0, "人事室主管", ""),
         admin9_txt = if_else(admin9 == 0, "主（會）計室主管", "")) %>%
  mutate(flag1 = paste("尚待增補之學校主管：", admin1_txt, admin2_txt, admin3_txt, admin4_txt, admin5_txt, admin6_txt, admin7_txt, admin8_txt, admin9_txt, sep = " ")) %>%
  mutate(flag1 = recode(gsub("\\s+", " ", flag1), `尚待增補之學校主管： ` = "")) %>%
  mutate(flag1 = if_else(flag1 != "", paste(flag1, "（請確認是否填報完整名單，倘貴校上開主任尚未到職，請來電告知）", sep = ""), flag1)) %>%
  subset(select = c(organization_id, flag1)) %>%
  distinct(organization_id, flag1)

flag1$flag1 <- gsub("： ", replacement="：", flag1$flag1)
flag1$flag1 <- gsub(" （", replacement="（", flag1$flag1)


#偵測flag1是否存在。若不存在，則產生NA行
if('flag1' %in% ls()){
  print("flag1")
}else{
  flag1 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag1$flag1 <- ""
}

# flag2: 設有專業類科二科以上的高級中等學校，本校應設有科主任（或有同類學程時應設有學程主任）。 -------------------------------------------------------------------
  #flag2_append-------------------------------------------------------------------
data_schtype_wide_flag2 <- aggregate(typeV ~ organization_id + type_code, data_schtype_wide, sum) %>%
  subset(type_code == "V" & typeV >= 2) %>%
  rename(flag_typeV = typeV)

flag_person <- drev_person_1
flag_person <- merge(x = flag_person, y = data_schtype_wide_flag2, by = c("organization_id"), all.x = TRUE)

flag_person$err_flag <- case_when(
  flag_person$flag_typeV >= 2 ~ 1,
  TRUE ~ 0
)
  #---

temp <- c("0", "1", "2", "3")
for (x in temp){
  flag_person$err_flag <- case_when(
    (grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) | (grepl("主任", flag_person[[paste("admintitle", x, sep = "")]]) & grepl("科$", flag_person[[paste("adminunit", x, sep = "")]]))) & flag_person$flag_typeV >= 2 ~ 0,
    TRUE ~ flag_person$err_flag
  )
}  

flag2 <- flag_person %>%
  group_by(organization_id) %>%
  mutate(err_flag = min(err_flag)) %>%
  mutate(flag2 = if_else(err_flag == 1,"請學校確認是否設置科主任或學程主任", "")) %>%
  subset(select = c(organization_id, flag2)) %>%
  distinct(organization_id, flag2)

#偵測flag2是否存在。若不存在，則產生NA行
if('flag2' %in% ls()){
  print("flag2")
}else{
  flag2 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag2$flag2 <- ""
}

# flag3: 設有專門學程總班級數四班以上的高級中等學校，本校應設有學程主任。 -------------------------------------------------------------------
  #flag3_append-------------------------------------------------------------------
data_schtype_wide_flag3 <- data_schtype_wide %>%
  subset(dep1_code != "11")
  
data_schtype_wide_flag3 <- aggregate(nclass ~ organization_id + type_code, data_schtype_wide_flag3, sum) %>%
  rename(flag_nclass = nclass) %>%
  subset(type_code == "M" & flag_nclass >= 4) %>%
  distinct(organization_id, .keep_all = TRUE)

flag_person <- drev_person_1
flag_person <- merge(x = flag_person, y = data_schtype_wide_flag3, by = c("organization_id"), all.x = TRUE)

flag_person$err_flag <- case_when(
  (flag_person$type_code == "M" & flag_person$flag_nclass >= 4) ~ 1,
  TRUE ~ 0
)
  #---

temp <- c("0", "1", "2", "3")
for (x in temp){
  flag_person$err_flag <- case_when(
    grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) & (flag_person$type_code == "M" & flag_person$flag_nclass >= 4) ~ 0,
    TRUE ~ flag_person$err_flag
  )
}  

flag3 <- flag_person %>%
  group_by(organization_id) %>%
  mutate(err_flag = min(err_flag)) %>%
  mutate(flag3 = if_else(err_flag == 1,"請學校確認是否設置學程主任", "")) %>%
  subset(select = c(organization_id, flag3)) %>%
  distinct(organization_id, flag3)

#偵測flag3是否存在。若不存在，則產生NA行
if('flag3' %in% ls()){
  print("flag3")
}else{
  flag3 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag3$flag3 <- ""
}

# flag6: 人事資料表的姓名應為中文或英文，不得有亂碼。 -------------------------------------------------------------------
  #flag6_append-------------------------------------------------------------------
flag_person <- drev_person_1

#檢視姓名欄位字元數不為3
view_flag6 <- distinct(flag_person, name, .keep_all = TRUE) %>%
  subset(nchar(name) != 3) %>%
  subset(select = c(organization_id, idnumber, name, edu_name2, source))

#數字、特殊符號標記為1(不包含．)
flag_person$err_flag <- grepl("\\d|[[:punct:]&&[^.]]", flag_person$name) %>% as.integer()

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag6 <- flag_person %>%
  subset(select = c(organization_id, idnumber, name, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ name, value.var = "name")

#合併所有name
temp <- colnames(flag_person_wide_flag6)[3 : length(colnames(flag_person_wide_flag6))]
flag_person_wide_flag6$flag6_r <- NA
for (i in temp){
  flag_person_wide_flag6$flag6_r <- paste(flag_person_wide_flag6$flag6_r, flag_person_wide_flag6[[i]], sep = " ")
}
flag_person_wide_flag6$flag6_r <- gsub("NA ", replacement="", flag_person_wide_flag6$flag6_r)
flag_person_wide_flag6$flag6_r <- gsub(" NA", replacement="", flag_person_wide_flag6$flag6_r)

#產生檢誤報告文字
flag6_temp <- flag_person_wide_flag6 %>%
  group_by(organization_id) %>%
  mutate(flag6_txt = paste(source, "需修改姓名處：", flag6_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag6_txt)) %>%
  distinct(organization_id, flag6_txt)

#根據organization_id，展開成寬資料(wide)
flag6 <- flag6_temp %>%
  dcast(organization_id ~ flag6_txt, value.var = "flag6_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag6)[2 : length(colnames(flag6))]
flag6$flag6 <- NA
for (i in temp){
  flag6$flag6 <- paste(flag6$flag6, flag6[[i]], sep = "； ")
}
flag6$flag6 <- gsub("NA； ", replacement="", flag6$flag6)
flag6$flag6 <- gsub("； NA", replacement="", flag6$flag6)

#產生檢誤報告文字
flag6 <- flag6 %>%
  subset(select = c(organization_id, flag6)) %>%
  distinct(organization_id, flag6)
}else{
#偵測flag6是否存在。若不存在，則產生NA行
if('flag6' %in% ls()){
  print("flag6")
}else{
  flag6 <- drev_person_1 %>%
  distinct(organization_id, .keep_all = TRUE) %>%
  subset(select = c(organization_id))
  flag6$flag6 <- ""
}
}
# flag7: 出生年月日換算成年齡後，偏高或偏低。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$survey_year <- 112
flag_person$birthy <- substr(flag_person$birthdate, 1, 3) %>% as.numeric()

flag_person$age <- flag_person$survey_year- flag_person$birthy

#錯誤標記
flag_person$irr_year <- 0
flag_person$irr_year <- if_else(flag_person$age < 18, 1, flag_person$irr_year)
flag_person$irr_year <- if_else(flag_person$age > 75, 1, flag_person$irr_year)
flag_person$irr_year <- if_else(flag_person$age > 75 & (flag_person$emptype == "兼任" | flag_person$emptype == "長期代課" | flag_person$emptype == "專職族語老師" | flag_person$emptype == "鐘點教師" | flag_person$emptype == "約聘僱" | flag_person$emptype == "約用" | flag_person$emptype == "派遣"), 0, flag_person$irr_year)
flag_person$irr_year <- if_else(flag_person$age > 85 & (flag_person$emptype == "兼任" | flag_person$emptype == "長期代課" | flag_person$emptype == "專職族語老師" | flag_person$emptype == "鐘點教師" | flag_person$emptype == "約聘僱" | flag_person$emptype == "約用" | flag_person$emptype == "派遣"), 1, flag_person$irr_year)

#姓名加註出生年月日
flag_person$name <- case_when(
  flag_person$irr_year == 1 ~ paste(flag_person$name, "（", flag_person$birthdate, "）", sep = ""),
  TRUE ~ flag_person$name
)

if (dim(flag_person %>% subset(irr_year == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_flag7 <- flag_person %>%
  subset(select = c(organization_id, idnumber, name, edu_name2, source, irr_year)) %>%
  subset(irr_year == 1) %>%
  dcast(organization_id + source ~ name, value.var = "name")

#合併所有name
temp <- colnames(flag_person_flag7)[3 : length(colnames(flag_person_flag7))]
flag_person_flag7$flag7_r <- NA
for (i in temp){
  flag_person_flag7$flag7_r <- paste(flag_person_flag7$flag7_r, flag_person_flag7[[i]], sep = " ")
}
flag_person_flag7$flag7_r <- gsub("NA ", replacement="", flag_person_flag7$flag7_r)
flag_person_flag7$flag7_r <- gsub(" NA", replacement="", flag_person_flag7$flag7_r)

#產生檢誤報告文字
flag7_temp <- flag_person_flag7 %>%
  group_by(organization_id) %>%
  mutate(flag7_txt = paste(source, "：", flag7_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag7_txt)) %>%
  distinct(organization_id, flag7_txt)

#根據organization_id，展開成寬資料(wide)
flag7 <- flag7_temp %>%
  dcast(organization_id ~ flag7_txt, value.var = "flag7_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag7)[2 : length(colnames(flag7))]
flag7$flag7 <- NA
for (i in temp){
  flag7$flag7 <- paste(flag7$flag7, flag7[[i]], sep = "； ")
}
flag7$flag7 <- gsub("NA； ", replacement="", flag7$flag7)
flag7$flag7 <- gsub("； NA", replacement="", flag7$flag7)

#產生檢誤報告文字
flag7 <- flag7 %>%
  subset(select = c(organization_id, flag7)) %>%
  distinct(organization_id, flag7) %>%
  mutate(flag7 = paste(flag7, "（請確認出生年月日是否正確）", sep = ""))
}else{
#偵測flag7是否存在。若不存在，則產生NA行
if('flag7' %in% ls()){
  print("flag7")
}else{
  flag7 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag7$flag7 <- ""
}
}
# flag8: 國籍別應填入「本國籍」或者外交部網站之世界各國名稱一覽表的國家名稱（或者至少須足以辨識國家）。 -------------------------------------------------------------------
  #flag8_append-------------------------------------------------------------------
flag_person <- drev_person_1

  #檢視國籍別欄位字元數不為3
view_flag8 <- distinct(flag_person, nation, .keep_all = TRUE) %>%
  subset(nchar(nation) != 3) %>%
  subset(select = c(organization_id, idnumber, nation, edu_name2, source))

  #不合理的情形標記為1
flag_person$err_flag <- case_when(
  flag_person$nation == "外籍" ~ 1,
  flag_person$nation == "外國籍" ~ 1,
  flag_person$nation == "國外" ~ 1,
  flag_person$nation == "外國" ~ 1,
  flag_person$nation == "國內" ~ 1,
  grepl("雙重", flag_person$nation) ~ 1,
  flag_person$nation == "N" ~ 1,
  TRUE ~ 0
)

  #flag98比對用
flag_person_flag8 <- flag_person %>%
  subset(err_flag == 1) %>%
  select("idnumber", "err_flag")

  #加註
flag_person$name <- paste(flag_person$name, "（", flag_person$nation, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)


if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag8 <- flag_person %>%
  subset(select = c(organization_id, idnumber, name, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ name, value.var = "name")

#合併所有name
temp <- colnames(flag_person_wide_flag8)[3 : length(colnames(flag_person_wide_flag8))]
flag_person_wide_flag8$flag8_r <- NA
for (i in temp){
  flag_person_wide_flag8$flag8_r <- paste(flag_person_wide_flag8$flag8_r, flag_person_wide_flag8[[i]], sep = " ")
}
flag_person_wide_flag8$flag8_r <- gsub("NA ", replacement="", flag_person_wide_flag8$flag8_r)
flag_person_wide_flag8$flag8_r <- gsub(" NA", replacement="", flag_person_wide_flag8$flag8_r)

#產生檢誤報告文字
flag8_temp <- flag_person_wide_flag8 %>%
  group_by(organization_id) %>%
  mutate(flag8_txt = paste(source, "需修改國籍別處：", flag8_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag8_txt)) %>%
  distinct(organization_id, flag8_txt)

#根據organization_id，展開成寬資料(wide)
flag8 <- flag8_temp %>%
  dcast(organization_id ~ flag8_txt, value.var = "flag8_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag8)[2 : length(colnames(flag8))]
flag8$flag8 <- NA
for (i in temp){
  flag8$flag8 <- paste(flag8$flag8, flag8[[i]], sep = "； ")
}
flag8$flag8 <- gsub("NA； ", replacement="", flag8$flag8)
flag8$flag8 <- gsub("； NA", replacement="", flag8$flag8)

#產生檢誤報告文字
flag8 <- flag8 %>%
  subset(select = c(organization_id, flag8)) %>%
  distinct(organization_id, flag8)
}else{
#偵測flag8是否存在。若不存在，則產生NA行
if('flag8' %in% ls()){
  print("flag8")
}else{
  flag8 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag8$flag8 <- ""
}
}
# flag9: 博士、碩士、學士、副學士畢業學校國別（一）～（二）應填入「本國」或者外交部網站之世界各國名稱一覽表的國家名稱（或者至少須足以辨識國家）。 -------------------------------------------------------------------
  #flag9_append-------------------------------------------------------------------
flag_person <- drev_person_1

#檢視畢業學校國別欄位字元數不為3
view_flag9 <- distinct(flag_person, ddegreen1, ddegreen2, mdegreen1, mdegreen2, bdegreen1, bdegreen2, adegreen1, adegreen2, .keep_all = TRUE) %>%
  subset(nchar(ddegreen1) != 3 | nchar(ddegreen2) != 3 | nchar(mdegreen1) != 3 | nchar(mdegreen2) != 3 | nchar(bdegreen1) != 3 | nchar(bdegreen2) != 3 | nchar(adegreen1) != 3 | nchar(adegreen2) != 3) %>%
  subset(select = c(organization_id, idnumber, ddegreen1, ddegreen2, mdegreen1, mdegreen2, bdegreen1, bdegreen2, adegreen1, adegreen2, edu_name2, source))

#"本國美國"標記為1
flag_person$err_flag <- case_when(
  flag_person$ddegreen1 == "本國美國" | flag_person$ddegreen2 == "本國美國" | flag_person$mdegreen1 == "本國美國" | flag_person$mdegreen2 == "本國美國" | flag_person$bdegreen1 == "本國美國" | flag_person$bdegreen2 == "本國美國" | flag_person$adegreen1 == "本國美國" | flag_person$adegreen2 == "本國美國" ~ 1,
    TRUE ~ 0
)
  #---

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag9 <- flag_person %>%
  subset(select = c(organization_id, idnumber, name, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ name, value.var = "name")

#合併所有name
temp <- colnames(flag_person_wide_flag9)[3 : length(colnames(flag_person_wide_flag9))]
flag_person_wide_flag9$flag9_r <- NA
for (i in temp){
  flag_person_wide_flag9$flag9_r <- paste(flag_person_wide_flag9$flag9_r, flag_person_wide_flag9[[i]], sep = " ")
}
flag_person_wide_flag9$flag9_r <- gsub("NA ", replacement="", flag_person_wide_flag9$flag9_r)
flag_person_wide_flag9$flag9_r <- gsub(" NA", replacement="", flag_person_wide_flag9$flag9_r)

#產生檢誤報告文字
flag9_temp <- flag_person_wide_flag9 %>%
  group_by(organization_id) %>%
  mutate(flag9_txt = paste(source, "需修改畢業學校國別者：", flag9_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag9_txt)) %>%
  distinct(organization_id, flag9_txt)

#根據organization_id，展開成寬資料(wide)
flag9 <- flag9_temp %>%
  dcast(organization_id ~ flag9_txt, value.var = "flag9_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag9)[2 : length(colnames(flag9))]
flag9$flag9 <- NA
for (i in temp){
  flag9$flag9 <- paste(flag9$flag9, flag9[[i]], sep = "； ")
}
flag9$flag9 <- gsub("NA； ", replacement="", flag9$flag9)
flag9$flag9 <- gsub("； NA", replacement="", flag9$flag9)

#產生檢誤報告文字
flag9 <- flag9 %>%
  subset(select = c(organization_id, flag9)) %>%
  distinct(organization_id, flag9)
}else{
#偵測flag9是否存在。若不存在，則產生NA行
if('flag9' %in% ls()){
  print("flag9")
}else{
  flag9 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag9$flag9 <- ""
}
}
# flag15: 兼任行政職職稱（一）～（三）不應填入校長或非行政職職稱，例如老師、教師、運動教練等。 -------------------------------------------------------------------
  #flag15_append-------------------------------------------------------------------
flag_person <- drev_person_1

#"本國美國"標記為1
flag_person$err_flag_admintitle1 <- 0
flag_person$err_flag_admintitle2 <- 0
flag_person$err_flag_admintitle3 <- 0
flag_person$err_flag_admintitle1 <- case_when(
  grepl("教學支援工作人員$", flag_person$admintitle1) | grepl("教學支援人員$", flag_person$admintitle1) | grepl("老師$", flag_person$admintitle1) | grepl("教師$", flag_person$admintitle1) | grepl("導師", flag_person$admintitle1) | grepl("運動教練", flag_person$admintitle1) | grepl("^校長$", flag_person$admintitle1) | grepl("教官$", flag_person$admintitle1) ~ 1,
  TRUE ~ flag_person$err_flag_admintitle1
)
flag_person$err_flag_admintitle2 <- case_when(
  grepl("教學支援工作人員$", flag_person$admintitle2) | grepl("教學支援人員$", flag_person$admintitle2) | grepl("老師$", flag_person$admintitle2) | grepl("教師$", flag_person$admintitle2) | grepl("導師", flag_person$admintitle2) | grepl("運動教練", flag_person$admintitle2) | grepl("^校長$", flag_person$admintitle2) | grepl("教官$", flag_person$admintitle2) ~ 1,
  TRUE ~ flag_person$err_flag_admintitle2
)
flag_person$err_flag_admintitle3 <- case_when(
  grepl("教學支援工作人員$", flag_person$admintitle3) | grepl("教學支援人員$", flag_person$admintitle3) | grepl("老師$", flag_person$admintitle3) | grepl("教師$", flag_person$admintitle3) | grepl("導師", flag_person$admintitle3) | grepl("運動教練", flag_person$admintitle3) | grepl("^校長$", flag_person$admintitle3) | grepl("教官$", flag_person$admintitle3) ~ 1,
  TRUE ~ flag_person$err_flag_admintitle3
)

flag_person$err_flag <- flag_person$err_flag_admintitle1 + flag_person$err_flag_admintitle2 + flag_person$err_flag_admintitle3

#加註職稱
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag_admintitle1 == 1 ~ paste(flag_person$name, "（", flag_person$admintitle1, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag_admintitle2 == 1 ~ paste(flag_person$name, "（", flag_person$admintitle2, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag_admintitle3 == 1 ~ paste(flag_person$name, "（", flag_person$admintitle3, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)
  #---

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag15 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag15)[3 : length(colnames(flag_person_wide_flag15))]
flag_person_wide_flag15$flag15_r <- NA
for (i in temp){
  flag_person_wide_flag15$flag15_r <- paste(flag_person_wide_flag15$flag15_r, flag_person_wide_flag15[[i]], sep = " ")
}
flag_person_wide_flag15$flag15_r <- gsub("NA ", replacement="", flag_person_wide_flag15$flag15_r)
flag_person_wide_flag15$flag15_r <- gsub(" NA", replacement="", flag_person_wide_flag15$flag15_r)

#產生檢誤報告文字
flag15_temp <- flag_person_wide_flag15 %>%
  group_by(organization_id) %>%
  mutate(flag15_txt = paste(source, "需修改兼任行政職職稱：", flag15_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag15_txt)) %>%
  distinct(organization_id, flag15_txt)

#根據organization_id，展開成寬資料(wide)
flag15 <- flag15_temp %>%
  dcast(organization_id ~ flag15_txt, value.var = "flag15_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag15)[2 : length(colnames(flag15))]
flag15$flag15 <- NA
for (i in temp){
  flag15$flag15 <- paste(flag15$flag15, flag15[[i]], sep = "； ")
}
flag15$flag15 <- gsub("NA； ", replacement="", flag15$flag15)
flag15$flag15 <- gsub("； NA", replacement="", flag15$flag15)

#產生檢誤報告文字
flag15 <- flag15 %>%
  subset(select = c(organization_id, flag15)) %>%
  distinct(organization_id, flag15) %>%
  mutate(flag15 = paste(flag15, "（校長、教師、教官、主任教官、族語老師、教學支援人員屬於服務身分別，若渠等教員未再兼任行政職務，如秘書、學務主任、生活輔導組組長等，請於兼任行政職職稱(單位)填“N” ）", sep = ""))
}else{
#偵測flag15是否存在。若不存在，則產生NA行
if('flag15' %in% ls()){
  print("flag15")
}else{
  flag15 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag15$flag15 <- ""
}
}
# flag16: 請假類別應依《教師請假規則》、《公務人員請假規則》以及人事行政主管機關公教員工請假給假一覽表相關規定填列。 -------------------------------------------------------------------
flag_person <- drev_person_1
  
#標記各種假別為1
flag_person$err_flag <- 1
flag_person$err_flag <- if_else(flag_person$leave == "事假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "家庭照顧假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "病假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "延長病假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "普通傷病假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "生理假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "婚假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "娩假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "分娩假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "產前假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "陪產假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "流產假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "安胎假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "喪假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "休假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "捐贈器官或骨髓假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "公假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "特別休假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "特休", 0, flag_person$err_flag)
#衛理女中確實核給"延長重病假"
flag_person$err_flag <- if_else(flag_person$leave == "延長重病假" & flag_person$organization_id == "411302", 0, flag_person$err_flag)

flag_person$err_flag <- if_else(flag_person$leave == "延長病假(安胎)", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "公假(公傷假)", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "公(傷)假", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$leave == "安胎病假、產前假、娩假", 0, flag_person$err_flag)

flag_person$err_flag <- if_else(grepl("留職停薪$", flag_person$leave) | grepl("留停$", flag_person$leave), 0, flag_person$err_flag)

flag_person$err_flag <- if_else(grepl("^育嬰假$", flag_person$leave) & flag_person$levpay == "育嬰留職停薪", 0, flag_person$err_flag)

flag_person$err_flag <- if_else(flag_person$leave == "N", 0, flag_person$err_flag)


#加註請假類別
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ paste(flag_person$name, "（", flag_person$leave, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag16 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
#合併所有name
temp <- colnames(flag_person_wide_flag16)[3 : length(colnames(flag_person_wide_flag16))]
flag_person_wide_flag16$flag16_r <- NA
for (i in temp){
  flag_person_wide_flag16$flag16_r <- paste(flag_person_wide_flag16$flag16_r, flag_person_wide_flag16[[i]], sep = " ")
}
flag_person_wide_flag16$flag16_r <- gsub("NA ", replacement="", flag_person_wide_flag16$flag16_r)
flag_person_wide_flag16$flag16_r <- gsub(" NA", replacement="", flag_person_wide_flag16$flag16_r)
  
#產生檢誤報告文字
flag16_temp <- flag_person_wide_flag16 %>%
  group_by(organization_id) %>%
  mutate(flag16_txt = paste(source, "需修改請假類別：", flag16_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag16_txt)) %>%
  distinct(organization_id, flag16_txt)
  
#根據organization_id，展開成寬資料(wide)
flag16 <- flag16_temp %>%
  dcast(organization_id ~ flag16_txt, value.var = "flag16_txt")
  
#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag16)[2 : length(colnames(flag16))]
flag16$flag16 <- NA
for (i in temp){
  flag16$flag16 <- paste(flag16$flag16, flag16[[i]], sep = "； ")
}
flag16$flag16 <- gsub("NA； ", replacement="", flag16$flag16)
flag16$flag16 <- gsub("； NA", replacement="", flag16$flag16)
  
#產生檢誤報告文字
flag16 <- flag16 %>%
  subset(select = c(organization_id, flag16)) %>%
  distinct(organization_id, flag16) %>%
  mutate(flag16 = paste(flag16, "（請確認請假類別，或是否屬於請假，若以上人員未有請假情事，請填寫半型大寫『N』）", sep = ""))
}else{
#偵測flag16是否存在。若不存在，則產生NA行
if('flag16' %in% ls()){
  print("flag16")
}else{
  flag16 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag16$flag16 <- ""
}
}
# flag18: 人事資料表各欄位是否有資料分布異常的情形。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$count_emptype <- if_else(flag_person$emptype == "專任" & flag_person$source == "教員資料表", 1, 0)
flag_person$count_emptype2 <- if_else(flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, 0)
flag_person$count_empunit <- if_else((flag_person$empunit == "高中部日間部" | flag_person$empunit == "國中部日間部" | flag_person$empunit == "中學部") & flag_person$source == "教員資料表", 1, 0)
flag_person$count_empunit2 <- if_else((flag_person$empunit == "高中部日間部" | flag_person$empunit == "國中部日間部" | flag_person$empunit == "中學部") & flag_person$source == "職員(工)資料表", 1, 0)
flag_person$count_sertype <- if_else(flag_person$sertype == "教師", 1, 0)
flag_person$count_sertype2 <- if_else(flag_person$sertype == "校長", 1, 0)
flag_person$count_skillteacher <- if_else(flag_person$skillteacher == "N", 1, 0)
flag_person$count_counselor <- if_else(flag_person$counselor == "N", 1, 0)
flag_person$count_speteacher <- if_else(flag_person$speteacher == "N", 1, 0)
flag_person$count_joiteacher <- if_else(flag_person$joiteacher %in% c("1", "2"), 1, 0)
flag_person$count_joiteacher2 <- if_else(flag_person$joiteacher %in% c("3", "4"), 1, 0)
flag_person$count_joiteacher3 <- if_else(flag_person$joiteacher == "N", 1, 0)
flag_person$count_expecter <- if_else(flag_person$expecter == "N", 1, 0)
flag_person$count_workexp <- if_else(flag_person$workexp == "N", 1, 0)
flag_person$count_study <- if_else(flag_person$study == "N", 1, 0)

flag_person <- flag_person %>%
  mutate(count_admin2 = 0, count_admin3 = 0, count_admin4 = 0, count_admin5 = 0, count_admin6 = 0, count_admin8 = 0, count_admin9 = 0)

temp <- c("0", "1", "2", "3")
for (x in temp){
  flag_person$count_admin2 <- case_when(
    grepl("教務", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("國中部主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin2
  )
}     
for (x in temp){
  flag_person$count_admin3 <- case_when(
    (grepl("學務", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("學生事務", flag_person[[paste("adminunit", x, sep = "")]]))                                                                & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin3
  )
}                
for (x in temp){
  flag_person$count_admin4 <- case_when(
    grepl("總務", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin4
  )
}                
for (x in temp){
  flag_person$count_admin5 <- case_when(
    grepl("輔導", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                     & (grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任輔導教師$", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin5
  )
}                
for (x in temp){
  flag_person$count_admin6 <- case_when(
    (grepl("圖書", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("圖資", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("圖書資訊", flag_person[[paste("adminunit", x, sep = "")]])) & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^館長$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin6
  )
}  
for (x in temp){  
  flag_person$count_admin8 <- case_when(
    grepl("人事", flag_person[[paste("adminunit", x, sep = "")]])                                                                                                                                      & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^人事管理員$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin8
  )
}                
for (x in temp){
  flag_person$count_admin9 <- case_when(
    (grepl("會計", flag_person[[paste("adminunit", x, sep = "")]]) | grepl("主計", flag_person[[paste("adminunit", x, sep = "")]]))                                                                    & ((grepl("主任$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("主任1$", flag_person[[paste("admintitle", x, sep = "")]])) & !grepl("主任教官", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("科主任", flag_person[[paste("admintitle", x, sep = "")]]) & !grepl("學程主任", flag_person[[paste("admintitle", x, sep = "")]])) | grepl("^主計員$", flag_person[[paste("admintitle", x, sep = "")]]) | grepl("^主計員$", flag_person[[paste("admintitle", x, sep = "")]]) ~ 1,
    TRUE ~ flag_person$count_admin9
  )
}  

#調整NA
temp <- c("count_emptype", "count_empunit", "count_sertype", "count_sertype2", "count_skillteacher", "count_counselor", "count_speteacher", "count_counselor", "count_speteacher", "count_joiteacher", "count_joiteacher2", "count_joiteacher3", "count_expecter", "count_workexp", "count_study", "count_admin2", "count_admin3", "count_admin4", "count_admin5", "count_admin6", "count_admin8", "count_admin9")
for (x in temp){
  flag_person[[x]][is.na(flag_person[[x]])] <- 0
}

flag_person$jj <- 1

flag_person_wide_flag18 <- aggregate(cbind(count_emptype, count_emptype2, count_empunit, count_empunit2, count_sertype, count_sertype2, count_skillteacher, count_counselor, count_speteacher, count_joiteacher, count_joiteacher2, count_joiteacher3, count_expecter, count_workexp, count_study, count_admin2, count_admin3, count_admin4, count_admin5, count_admin6, count_admin8, count_admin9, jj) ~ organization_id + source, flag_person, sum)

flag_person_wide_flag18$flag_err <- 0
flag_person_wide_flag18$err_emptype <- if_else(flag_person_wide_flag18$count_emptype / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "教員資料表專任教學人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整教員名單資料。", "")
flag_person_wide_flag18$err_emptype2 <- if_else(flag_person_wide_flag18$count_emptype2 / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "職員(工)資料表", "職員(工)資料表專任人員人數偏低，請再協助確認實際聘任情況，或請確認是否填報完整職員(工)名單資料。", "")
flag_person_wide_flag18$err_empunit <- if_else(flag_person_wide_flag18$count_empunit / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "教員資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_empunit2 <- if_else(flag_person_wide_flag18$count_empunit2 / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "職員(工)資料表", "職員(工)資料表主聘單位各類別人數分布異常，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_sertype <- if_else(flag_person_wide_flag18$count_sertype / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "教師人數偏低，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_sertype2 <- if_else(flag_person_wide_flag18$count_sertype2 > 1 & flag_person_wide_flag18$source == "教員資料表", "校長人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_skillteacher <- if_else(flag_person_wide_flag18$count_skillteacher / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "專業及技術教師人數偏多，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_counselor <- if_else(flag_person_wide_flag18$count_counselor / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "專任輔導教師人數偏多，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_speteacher <- if_else(flag_person_wide_flag18$count_speteacher / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "特教班專職教師人數偏多，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_joiteacher <- if_else(flag_person_wide_flag18$count_joiteacher / flag_person_wide_flag18$jj > 0.1 & flag_person_wide_flag18$source == "教員資料表", "合聘教師人數偏多（請確認校內教師是否與他校合聘：如有與他校合聘者，本校又為『主聘學校』，再請於『是否為合聘教師』一欄填入『1』，若以本校為『從聘學校』請於『是否為合聘教師』一欄填入『2』；若沒有與他校合聘，則『是否為合聘教師』一欄請填『N』）", "")
flag_person_wide_flag18$err_joiteacher2 <- if_else(flag_person_wide_flag18$count_joiteacher2 / flag_person_wide_flag18$jj > 0.2 & flag_person_wide_flag18$source == "教員資料表", "巡迴教師人數偏多（請確認校內巡迴教師人數：如有巡迴教師，以本校又為『中心學校』，再請於『是否為合聘教師』一欄填入『3』，若以本校為『從屬學校』請於『是否為合聘教師』一欄填入『4』；若沒有巡迴教師，則『是否為合聘教師』一欄請填『N』）", "")
flag_person_wide_flag18$err_joiteacher3 <- if_else(flag_person_wide_flag18$count_joiteacher3 / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "合聘教師與巡迴教師人數偏多（請確認校內合聘教師、巡迴教師情形）", "")
flag_person_wide_flag18$err_expecter <- if_else(flag_person_wide_flag18$count_expecter / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "業界專家人數偏多，請再協助確認實際聘任情況，或請確認是否將專業及技術教師誤填為業界專家。", "")
flag_person_wide_flag18$err_workexp <- if_else(flag_person_wide_flag18$count_workexp / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "一年以上與任教領域相關之業界實務工作經驗人數偏多（請再協助確認，『是否具備一年以上與任教領域相關之業界實務工作經驗』填寫『Y』之教員，是否確依欄位說明具備此經驗）", "")
flag_person_wide_flag18$err_study <- if_else(flag_person_wide_flag18$count_study / flag_person_wide_flag18$jj < 0.5 & flag_person_wide_flag18$source == "教員資料表", "近六年內進行與專業或技術有關之研習或研究的人數偏多，請再協助確認實際聘任情況。", "")

#如果err_joiteacher、err_joiteacher2、err_joiteacher3同時皆被抓出的調整
idx <- which(flag_person_wide_flag18$err_joiteacher != "" & flag_person_wide_flag18$err_joiteacher2 != "" & flag_person_wide_flag18$err_joiteacher3 != "")
flag_person_wide_flag18[idx, c("err_joiteacher", "err_joiteacher2")] <- ""

idx <- which(flag_person_wide_flag18$err_joiteacher != "" & flag_person_wide_flag18$err_joiteacher2 != "" & flag_person_wide_flag18$err_joiteacher3 == "")
flag_person_wide_flag18[idx, c("err_joiteacher", "err_joiteacher2")] <- ""
flag_person_wide_flag18[idx, c("err_joiteacher3")] <- "合聘教師與巡迴教師人數偏多（請確認校內合聘教師、巡迴教師情形）"

idx <- which(flag_person_wide_flag18$err_joiteacher != "" & flag_person_wide_flag18$err_joiteacher2 == "" & flag_person_wide_flag18$err_joiteacher3 != "")
flag_person_wide_flag18[idx, c("err_joiteacher")] <- ""

idx <- which(flag_person_wide_flag18$err_joiteacher == "" & flag_person_wide_flag18$err_joiteacher2 != "" & flag_person_wide_flag18$err_joiteacher3 != "")
flag_person_wide_flag18[idx, c("err_joiteacher2")] <- ""

flag_person_wide_flag18$err_admin2 <- if_else(flag_person_wide_flag18$count_admin2 > 1, "教務處主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin3 <- if_else(flag_person_wide_flag18$count_admin3 > 1, "學務處主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin4 <- if_else(flag_person_wide_flag18$count_admin4 > 1, "總務處主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin5 <- if_else(flag_person_wide_flag18$count_admin5 > 1, "輔導室主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin6 <- if_else(flag_person_wide_flag18$count_admin6 > 1, "圖書館主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin8 <- if_else(flag_person_wide_flag18$count_admin8 > 1, "人事室主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")
flag_person_wide_flag18$err_admin9 <- if_else(flag_person_wide_flag18$count_admin9 > 1, "主（會）計室主管（主任）人數超過一位，請再協助確認實際聘任情況。", "")


flag_person_wide_flag18$err_flag_txt <- paste(flag_person_wide_flag18$err_emptype, 
                                              flag_person_wide_flag18$err_emptype2, 
                                              flag_person_wide_flag18$err_empunit, 
                                              flag_person_wide_flag18$err_empunit2, 
                                              flag_person_wide_flag18$err_sertype, 
                                              flag_person_wide_flag18$err_sertype2, 
                                              flag_person_wide_flag18$err_admin2, 
                                              flag_person_wide_flag18$err_admin3, 
                                              flag_person_wide_flag18$err_admin4, 
                                              flag_person_wide_flag18$err_admin5, 
                                              flag_person_wide_flag18$err_admin6, 
                                              flag_person_wide_flag18$err_admin8, 
                                              flag_person_wide_flag18$err_admin9, 
                                              flag_person_wide_flag18$err_skillteacher, 
                                              flag_person_wide_flag18$err_counselor, 
                                              flag_person_wide_flag18$err_speteacher, 
                                              flag_person_wide_flag18$err_joiteacher, 
                                              flag_person_wide_flag18$err_joiteacher2, 
                                              flag_person_wide_flag18$err_joiteacher3, 
                                              flag_person_wide_flag18$err_expecter, 
                                              flag_person_wide_flag18$err_workexp, 
                                              flag_person_wide_flag18$err_study, sep = " ")

# #產生檢誤報告文字
# flag18_temp <- flag_person_wide_flag18 %>%
#   group_by(organization_id) %>%
#   mutate(flag18_txt = paste(source, "需修改請假類別：", flag18_r, sep = ""), "") %>%
#   subset(select = c(organization_id, flag18_txt)) %>%
#   distinct(organization_id, flag18_txt)

if (dim(flag_person %>% subset(grepl("\\S", flag_person_wide_flag18$err_flag_txt)))[1] != 0){
#根據organization_id，展開成寬資料(wide)
flag18 <- flag_person_wide_flag18 %>%
  subset(grepl("\\S", flag_person_wide_flag18$err_flag_txt)) %>%
  dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag18)[2 : length(colnames(flag18))]
flag18$flag18 <- NA
for (i in temp){
  flag18$flag18 <- paste(flag18$flag18, flag18[[i]], sep = "； ")
}
flag18$flag18 <- gsub("NA； ", replacement="", flag18$flag18)
flag18$flag18 <- gsub("； NA", replacement="", flag18$flag18)

#產生檢誤報告文字
flag18 <- flag18 %>%
  subset(select = c(organization_id, flag18)) %>%
  distinct(organization_id, flag18)

#刪除字串最後異常空格
trim_t <- function (x){
  gsub("\\s+|\\s+$", "", x)
}

flag18$flag18 <- trim_t(flag18$flag18) ##test
}else{
#偵測flag18是否存在。若不存在，則產生NA行
if('flag18' %in% ls()){
  print("flag18")
}else{
  flag18 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag18$flag18 <- ""
}
}
# flag19: 填寫外來人口統一證號者，國籍別應非「本國籍」。 -------------------------------------------------------------------
flag_person <- drev_person_1

#外來人口統一證號：第二碼為A B C D 8 9
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(grepl("^[^\\s][ABCD89][^\\s]+$", flag_person$idnumber) & (flag_person$nation %in% c("本國籍", "本國", "臺灣")), 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag19 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag19)[3 : length(colnames(flag_person_wide_flag19))]
flag_person_wide_flag19$flag19_r <- NA
for (i in temp){
  flag_person_wide_flag19$flag19_r <- paste(flag_person_wide_flag19$flag19_r, flag_person_wide_flag19[[i]], sep = " ")
}
flag_person_wide_flag19$flag19_r <- gsub("NA ", replacement="", flag_person_wide_flag19$flag19_r)
flag_person_wide_flag19$flag19_r <- gsub(" NA", replacement="", flag_person_wide_flag19$flag19_r)

#產生檢誤報告文字
flag19_temp <- flag_person_wide_flag19 %>%
  group_by(organization_id) %>%
  mutate(flag19_txt = paste(source, "：", flag19_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag19_txt)) %>%
  distinct(organization_id, flag19_txt)

#根據organization_id，展開成寬資料(wide)
flag19 <- flag19_temp %>%
  dcast(organization_id ~ flag19_txt, value.var = "flag19_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag19)[2 : length(colnames(flag19))]
flag19$flag19 <- NA
for (i in temp){
  flag19$flag19 <- paste(flag19$flag19, flag19[[i]], sep = "； ")
}
flag19$flag19 <- gsub("NA； ", replacement="", flag19$flag19)
flag19$flag19 <- gsub("； NA", replacement="", flag19$flag19)

#產生檢誤報告文字
flag19 <- flag19 %>%
  subset(select = c(organization_id, flag19)) %>%
  distinct(organization_id, flag19) %>%
  mutate(flag19 = paste(flag19, "（請確認且修正該員所屬國籍別）", sep = ""))
}else{
#偵測flag19是否存在。若不存在，則產生NA行
if('flag19' %in% ls()){
  print("flag19")
}else{
  flag19 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag19$flag19 <- ""
}
}
# flag20: 教職員工畢業學校若為專科學校，學歷資訊應於「副學士」畢業學校欄位填列。 -------------------------------------------------------------------
flag_person <- drev_person_1

#學士學位畢業學校名稱不可出現"專科學校"
flag_person$err_flag_bdegreeu1 <- 0
flag_person$err_flag_bdegreeu1 <- if_else(grepl("專科", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("二專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("五專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("海專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("工專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("商專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("藝專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("農專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("護專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("家專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("行專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("師專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("藥專", flag_person$bdegreeu1), 1, flag_person$err_flag_bdegreeu1)
flag_person$err_flag_bdegreeu1 <- if_else(grepl("^台南家專學校財團法人台南應用科技大學$", flag_person$bdegreeu1), 0, flag_person$err_flag_bdegreeu1)
#陸軍官校專科班為學士學位
flag_person$err_flag_bdegreeu1 <- if_else(grepl("^陸軍官校專科班$", flag_person$bdegreeu1), 0, flag_person$err_flag_bdegreeu1)

flag_person$err_flag_bdegreeu2 <- 0
flag_person$err_flag_bdegreeu2 <- if_else(grepl("專科", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("二專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("五專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("海專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("工專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("商專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("藝專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("農專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("護專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("家專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("行專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("師專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("藥專", flag_person$bdegreeu2), 1, flag_person$err_flag_bdegreeu2)
flag_person$err_flag_bdegreeu2 <- if_else(grepl("^台南家專學校財團法人台南應用科技大學$", flag_person$bdegreeu2), 0, flag_person$err_flag_bdegreeu2)
#陸軍官校專科班為學士學位
flag_person$err_flag_bdegreeu2 <- if_else(grepl("^陸軍官校專科班$", flag_person$bdegreeu2), 0, flag_person$err_flag_bdegreeu2)

flag_person$err_flag <- flag_person$err_flag_bdegreeu1 + flag_person$err_flag_bdegreeu2

#加註學士學位畢業學校名稱
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag_bdegreeu1 == 1 ~ paste(flag_person$name, "（學士學位畢業學校（一）：", flag_person$bdegreeu1, "）", sep = ""),
  flag_person$err_flag_bdegreeu2 == 1 ~ paste(flag_person$name, "（學士學位畢業學校（二）：", flag_person$bdegreeu2, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag20 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag20)[3 : length(colnames(flag_person_wide_flag20))]
flag_person_wide_flag20$flag20_r <- NA
for (i in temp){
  flag_person_wide_flag20$flag20_r <- paste(flag_person_wide_flag20$flag20_r, flag_person_wide_flag20[[i]], sep = " ")
}
flag_person_wide_flag20$flag20_r <- gsub("NA ", replacement="", flag_person_wide_flag20$flag20_r)
flag_person_wide_flag20$flag20_r <- gsub(" NA", replacement="", flag_person_wide_flag20$flag20_r)

#產生檢誤報告文字
flag20_temp <- flag_person_wide_flag20 %>%
  group_by(organization_id) %>%
  mutate(flag20_txt = paste(source, "：", flag20_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag20_txt)) %>%
  distinct(organization_id, flag20_txt)

#根據organization_id，展開成寬資料(wide)
flag20 <- flag20_temp %>%
  dcast(organization_id ~ flag20_txt, value.var = "flag20_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag20)[2 : length(colnames(flag20))]
flag20$flag20 <- NA
for (i in temp){
  flag20$flag20 <- paste(flag20$flag20, flag20[[i]], sep = "； ")
}
flag20$flag20 <- gsub("NA； ", replacement="", flag20$flag20)
flag20$flag20 <- gsub("； NA", replacement="", flag20$flag20)

#產生檢誤報告文字
flag20 <- flag20 %>%
  subset(select = c(organization_id, flag20)) %>%
  distinct(organization_id, flag20)
}else{
#偵測flag20是否存在。若不存在，則產生NA行
if('flag20' %in% ls()){
  print("flag20")
}else{
  flag20 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag20$flag20 <- ""
}
}
# flag24: 本校到職日期與填報基準日的差距，不應小於本校任職需扣除年資。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$survey_year <- 2023
flag_person$survey_mon <- 9
flag_person$onbodaty <- ""
flag_person$onbodatm <- ""
flag_person$onbodatd <- ""

flag_person$onbodaty <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 1, 2), flag_person$onbodaty)
flag_person$onbodatm <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 3, 4), flag_person$onbodatm)
flag_person$onbodatd <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 5, 6), flag_person$onbodatd)
flag_person$onbodaty <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 1, 3), flag_person$onbodaty)
flag_person$onbodatm <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 4, 5), flag_person$onbodatm)
flag_person$onbodatd <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 6, 7), flag_person$onbodatd)

flag_person$onbodaty <- as.numeric(flag_person$onbodaty)
flag_person$onbodatm <- as.numeric(flag_person$onbodatm)
flag_person$onbodatd <- as.numeric(flag_person$onbodatd)

#本校服務年資
flag_person$tser <- 0
flag_person$tser <- if_else(flag_person$survey_year %% 4 != 0, ((flag_person$survey_year-1911) + 9/12 + 30/365) - (flag_person$onbodaty + (flag_person$onbodatm/12) + (flag_person$onbodatd/365)), flag_person$tser)
flag_person$tser <- if_else(flag_person$survey_year %% 4 == 0, ((flag_person$survey_year-1911) + 9/12 + 30/366) - (flag_person$onbodaty + (flag_person$onbodatm/12) + (flag_person$onbodatd/366)), flag_person$tser)

#本次本校任職需扣除之年資
flag_person$desey <- substr(flag_person$desedym, 1, 2) %>% as.numeric()
flag_person$desem <- substr(flag_person$desedym, 3, 4) %>% as.numeric()

flag_person$dese <- (flag_person$desey + (flag_person$desem / 12))

#本校服務年資-本校任職需扣除之年資 才是實際在本校的服務年資
flag_person$tser <- flag_person$tser - flag_person$dese

#本校到職前學校服務總年資
flag_person$beoby <- substr(flag_person$beobdym, 1, 2) %>% as.numeric
flag_person$beobm <- substr(flag_person$beobdym, 3, 4) %>% as.numeric

flag_person$beob <- (flag_person$beoby + (flag_person$beobm / 12))

#學校教學工作總年資
flag_person$tsch <- flag_person$tser + flag_person$beob

#tser要小於-0.00137而不是0的原因：本校到職日期+本次本校任職需扣除之年資可能為4月1日，剛好超過資料基準日3月31日一天
#tser改成要小於-0.0041而不是-0.00137的原因：本校到職日期+本次本校任職需扣除之年資可能為10月1日，剛好超過資料基準日9月30日一天
#因扣除年資未滿一個月以一個月計，下學期基準日為2/28，可能造成誤差

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$tser < -.0806, 1, flag_person$err_flag)

#若spe3錯 則不應出現在flag24
flag_person$survey_year <- flag_person$survey_year - 1911

flag_person$arvy <- substr(flag_person$onbodat, 1, 3) %>% as.numeric()
flag_person$arvm <- substr(flag_person$onbodat, 4, 5) %>% as.numeric()

flag_person$err_spe = if_else((flag_person$arvy * 12 + flag_person$arvm) > (flag_person$survey_year * 12 + flag_person$survey_mon), 1, 0)

flag_person$err_flag <- if_else(flag_person$err_spe == 1, 0, flag_person$err_flag)

#換算到職至資料基準日的日期
flag_person$tser_ndese <- flag_person$tser + flag_person$dese
flag_person$tser_ndesey <- floor(flag_person$tser_ndese)
flag_person$tser_ndesem <- ceiling((flag_person$tser_ndese - floor(flag_person$tser_ndese)) * 12)
flag_person$ndesey <- floor(flag_person$dese)
flag_person$ndesem <- ceiling((flag_person$dese - floor(flag_person$dese)) * 12)

temp <- c("tser_ndesey", "tser_ndesem", "ndesey", "ndesem")
for (x in temp) {
  flag_person[[x]] <- flag_person[[x]] %>% as.character()
}

#加註到職至資料基準日的時間，和扣除年資
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ paste(flag_person$name, flag_person$onbodat,"到職（到職至資料基準日為", flag_person$tser_ndesey, "年", flag_person$tser_ndesem, "個月，但扣除年資為", flag_person$ndesey, "年", flag_person$ndesem, "個月", "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag24 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag24)[3 : length(colnames(flag_person_wide_flag24))]
flag_person_wide_flag24$flag24_r <- NA
for (i in temp){
  flag_person_wide_flag24$flag24_r <- paste(flag_person_wide_flag24$flag24_r, flag_person_wide_flag24[[i]], sep = " ")
}
flag_person_wide_flag24$flag24_r <- gsub("NA ", replacement="", flag_person_wide_flag24$flag24_r)
flag_person_wide_flag24$flag24_r <- gsub(" NA", replacement="", flag_person_wide_flag24$flag24_r)

#產生檢誤報告文字
flag24_temp <- flag_person_wide_flag24 %>%
  group_by(organization_id) %>%
  mutate(flag24_txt = paste(source, "：", flag24_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag24_txt)) %>%
  distinct(organization_id, flag24_txt)

#根據organization_id，展開成寬資料(wide)
flag24 <- flag24_temp %>%
  dcast(organization_id ~ flag24_txt, value.var = "flag24_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag24)[2 : length(colnames(flag24))]
flag24$flag24 <- NA
for (i in temp){
  flag24$flag24 <- paste(flag24$flag24, flag24[[i]], sep = "； ")
}
flag24$flag24 <- gsub("NA； ", replacement="", flag24$flag24)
flag24$flag24 <- gsub("； NA", replacement="", flag24$flag24)

#產生檢誤報告文字
flag24 <- flag24 %>%
  subset(select = c(organization_id, flag24)) %>%
  distinct(organization_id, flag24) %>%
  mutate(flag24 = paste("請確認該員之「本校到職日期」、「本校任職需扣除之年資」，", flag24, sep = ""))
}else{
#偵測flag24是否存在。若不存在，則產生NA行
if('flag24' %in% ls()){
  print("flag24")
}else{
  flag24 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag24$flag24 <- ""
}
}
# flag39: 學校工作總年資（本校服務年資+本校到職前學校服務總年資），與年齡之差距過大或過小。 -------------------------------------------------------------------
flag_person <- drev_person_1

#年齡
#創設變項出生年月日：birthy birthm birthd
flag_person$birthy <- ""
flag_person$birthm <- ""
flag_person$birthd <- ""

flag_person$birthy <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 1, 2), flag_person$birthy)
flag_person$birthm <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 3, 4), flag_person$birthm)
flag_person$birthd <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 5, 6), flag_person$birthd)
flag_person$birthy <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 1, 3), flag_person$birthy)
flag_person$birthm <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 4, 5), flag_person$birthm)
flag_person$birthd <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 6, 7), flag_person$birthd)

flag_person$birthy <- as.numeric(flag_person$birthy)
flag_person$birthm <- as.numeric(flag_person$birthm)
flag_person$birthd <- as.numeric(flag_person$birthd)

flag_person$survey_year <- 2023

#創設變項年齡（以年為單位）：age
flag_person$age <- 0
flag_person$age <- if_else(flag_person$survey_year %% 4 != 0, ((flag_person$survey_year-1911) + 9/12 + 30/365) - (flag_person$birthy + (flag_person$birthm/12) + (flag_person$birthd/365)), flag_person$age)
flag_person$age <- if_else(flag_person$survey_year %% 4 == 0, ((flag_person$survey_year-1911) + 9/12 + 30/366) - (flag_person$birthy + (flag_person$birthm/12) + (flag_person$birthd/366)), flag_person$age)

flag_person$onbodaty <- ""
flag_person$onbodatm <- ""
flag_person$onbodatd <- ""
flag_person$onbodatd <- ""

flag_person$onbodaty <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 1, 2), flag_person$onbodaty)
flag_person$onbodatm <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 3, 4), flag_person$onbodatm)
flag_person$onbodatd <- if_else(nchar(flag_person$onbodat) == 6, substr(flag_person$onbodat, 5, 6), flag_person$onbodatd)
flag_person$onbodaty <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 1, 3), flag_person$onbodaty)
flag_person$onbodatm <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 4, 5), flag_person$onbodatm)
flag_person$onbodatd <- if_else(nchar(flag_person$onbodat) == 7, substr(flag_person$onbodat, 6, 7), flag_person$onbodatd)

flag_person$onbodaty <- as.numeric(flag_person$onbodaty)
flag_person$onbodatm <- as.numeric(flag_person$onbodatm)
flag_person$onbodatd <- as.numeric(flag_person$onbodatd)

#本校服務年資
flag_person$tser <- 0
flag_person$tser <- if_else(flag_person$survey_year %% 4 != 0, ((flag_person$survey_year-1911) + 9/12 + 30/365) - (flag_person$onbodaty + (flag_person$onbodatm/12) + (flag_person$onbodatd/365)), flag_person$tser)
flag_person$tser <- if_else(flag_person$survey_year %% 4 == 0, ((flag_person$survey_year-1911) + 9/12 + 30/366) - (flag_person$onbodaty + (flag_person$onbodatm/12) + (flag_person$onbodatd/366)), flag_person$tser)

#本次本校任職需扣除之年資
flag_person$desey <- substr(flag_person$desedym, 1, 2) %>% as.numeric()
flag_person$desem <- substr(flag_person$desedym, 3, 4) %>% as.numeric()

flag_person$dese <- (flag_person$desey + (flag_person$desem / 12))

#本校服務年資-本校任職需扣除資年資 才是實際在本校的服務年資
flag_person$tser <- flag_person$tser - flag_person$dese

#避免掉年資小於零的情況（因本校到職日期+本次本校任職需扣除之年資可能為8/1的情況）
flag_person$tser <- if_else(flag_person$tser < 0, 0, flag_person$tser)

#本校到職前學校服務總年資
flag_person$beoby <- substr(flag_person$beobdym, 1, 2) %>% as.numeric
flag_person$beobm <- substr(flag_person$beobdym, 3, 4) %>% as.numeric

flag_person$beob <- (flag_person$beoby + (flag_person$beobm / 12))

#學校教學工作總年資
flag_person$tsch <- flag_person$tser + flag_person$beob

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$age - flag_person$tsch <= 17, 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$age - flag_person$tsch > 75, 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$age - flag_person$tsch > 75 & (flag_person$emptype == "兼任" | flag_person$emptype == "長期代課" | flag_person$emptype == "專職族語老師" | flag_person$emptype == "鐘點教師" | flag_person$emptype == "約聘僱" | flag_person$emptype == "約用" | flag_person$emptype == "派遣"), 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$age - flag_person$tsch > 85 & (flag_person$emptype == "兼任" | flag_person$emptype == "長期代課" | flag_person$emptype == "專職族語老師" | flag_person$emptype == "鐘點教師" | flag_person$emptype == "約聘僱" | flag_person$emptype == "約用" | flag_person$emptype == "派遣"), 1, flag_person$err_flag)

flag_person$age <- floor(flag_person$age)
flag_person$tsch <- floor(flag_person$tsch)
flag_person$gowork <- flag_person$age - flag_person$tsch

temp <- c("age", "tsch", "gowork")
for (x in temp) {
  flag_person[[x]] <- flag_person[[x]] %>% as.character()
}

#加註學校工作總年資及工作起始歲數
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ paste(flag_person$name, flag_person$age, "歲，但學校工作總年資有", flag_person$tsch, "年（約", flag_person$gowork, "歲開始工作）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag39 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag39)[3 : length(colnames(flag_person_wide_flag39))]
flag_person_wide_flag39$flag39_r <- NA
for (i in temp){
  flag_person_wide_flag39$flag39_r <- paste(flag_person_wide_flag39$flag39_r, flag_person_wide_flag39[[i]], sep = " ")
}
flag_person_wide_flag39$flag39_r <- gsub("NA ", replacement="", flag_person_wide_flag39$flag39_r)
flag_person_wide_flag39$flag39_r <- gsub(" NA", replacement="", flag_person_wide_flag39$flag39_r)

#產生檢誤報告文字
flag39_temp <- flag_person_wide_flag39 %>%
  group_by(organization_id) %>%
  mutate(flag39_txt = paste(source, "：", flag39_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag39_txt)) %>%
  distinct(organization_id, flag39_txt)

#根據organization_id，展開成寬資料(wide)
flag39 <- flag39_temp %>%
  dcast(organization_id ~ flag39_txt, value.var = "flag39_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag39)[2 : length(colnames(flag39))]
flag39$flag39 <- NA
for (i in temp){
  flag39$flag39 <- paste(flag39$flag39, flag39[[i]], sep = "； ")
}
flag39$flag39 <- gsub("NA； ", replacement="", flag39$flag39)
flag39$flag39 <- gsub("； NA", replacement="", flag39$flag39)

#產生檢誤報告文字
flag39 <- flag39 %>%
  subset(select = c(organization_id, flag39)) %>%
  distinct(organization_id, flag39) %>%
  mutate(flag39 = paste("請確認該員之「本校到職日期」、「本校任職需扣除之年資」、「本校到職前學校服務總年資」，", flag39, sep = ""))
}else{
#偵測flag39是否存在。若不存在，則產生NA行
if('flag39' %in% ls()){
  print("flag39")
}else{
  flag39 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag39$flag39 <- ""
}
}
# flag45: 聘任科別應填入服務身分別為「教師」、「主任教官」、「教官」之聘任科別中文名稱。 -------------------------------------------------------------------
flag_person <- drev_person_1

#聘任科別不合理處
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "NA" | flag_person$emsub == "N") & (flag_person$sertype == "教師" | flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "不分科") & (flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "教師") & (flag_person$sertype == "教師" | flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "教官") & (flag_person$sertype == "教師" | flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "主任教官") & (flag_person$sertype == "教師" | flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "副校長") & (flag_person$sertype == "教師" | flag_person$sertype == "主任教官" | flag_person$sertype == "教官"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("室$", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("處$", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^資處$", flag_person$emsub), 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("教官室", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("教務處", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("學務處", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("人事室", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("總務處", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("會計室", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("輔導室", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("實習處", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("圖書館", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("校長室", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("(全時支援他校)", flag_person$emsub), 0, flag_person$err_flag)

#社團 聘任類別為"鐘點教師"或"兼任"
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^社團$", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("社$", flag_person$emsub), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^管樂$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^合唱$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^中正之家$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^熱門音樂$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^吉他$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^魔術$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^話劇$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^國術$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^劍道$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^飛盤$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^機器人研究$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^儀隊$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & grepl("^滑板$", flag_person$emsub) & (flag_person$emptype == "鐘點教師" | flag_person$emptype == "兼任"), 1, flag_person$err_flag)
#「專門」指導學生「社團活動」之外聘指導教員，暫不納入填報。請依欄位說明，確認貴校教職員工名單是否正確。

#若校長的服務身份別填錯，且聘任科別填「NA」，則flag45不呈現，在flag47呈現
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "NA" | flag_person$emsub == "N") & (flag_person$sertype == "校長"), 0, flag_person$err_flag)
#若聘任科別填校長，需抓出
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & (flag_person$emsub == "校長"), 1, flag_person$err_flag)

#加註聘任科別
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ paste(flag_person$name, "（", flag_person$emsub, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag45 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag45)[3 : length(colnames(flag_person_wide_flag45))]
flag_person_wide_flag45$flag45_r <- NA
for (i in temp){
  flag_person_wide_flag45$flag45_r <- paste(flag_person_wide_flag45$flag45_r, flag_person_wide_flag45[[i]], sep = " ")
}
flag_person_wide_flag45$flag45_r <- gsub("NA ", replacement="", flag_person_wide_flag45$flag45_r)
flag_person_wide_flag45$flag45_r <- gsub(" NA", replacement="", flag_person_wide_flag45$flag45_r)

#產生檢誤報告文字
flag45_temp <- flag_person_wide_flag45 %>%
  group_by(organization_id) %>%
  mutate(flag45_txt = paste(source, "需修改聘任科別(括號內為該員所對應之聘任科別欄位內容)：", flag45_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag45_txt)) %>%
  distinct(organization_id, flag45_txt)

#根據organization_id，展開成寬資料(wide)
flag45 <- flag45_temp %>%
  dcast(organization_id ~ flag45_txt, value.var = "flag45_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag45)[2 : length(colnames(flag45))]
flag45$flag45 <- NA
for (i in temp){
  flag45$flag45 <- paste(flag45$flag45, flag45[[i]], sep = "； ")
}
flag45$flag45 <- gsub("NA； ", replacement="", flag45$flag45)
flag45$flag45 <- gsub("； NA", replacement="", flag45$flag45)

#（請依欄位說明，修正上開「教師」之聘任科別中文名稱）

#產生檢誤報告文字
flag45 <- flag45 %>%
  subset(select = c(organization_id, flag45)) %>%
  distinct(organization_id, flag45) %>%
  mutate(flag45 = paste(flag45, "（請依欄位說明，修正「教師」、「主任教官」、「教官」之聘任科別中文名稱，「教師」、「主任教官」、「教官」以外其他服務身分別教員之聘任科別請修正為NA。）", sep = ""))
}else{
#偵測flag45是否存在。若不存在，則產生NA行
if('flag45' %in% ls()){
  print("flag45")
}else{
  flag45 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag45$flag45 <- ""
}
}
# flag47: 兼任行政職職稱(一)若填寫“校長"，代表服務身分別填答有誤，故應核對服務身分別與兼任行政職職稱(一)。 -------------------------------------------------------------------
flag_person <- drev_person_1

#標記服務身分別不為"校長，且兼任行政職稱為"校長"
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$source == "教員資料表" & flag_person$sertype != "校長" & flag_person$admintitle1 == "校長", 1, flag_person$err_flag)

#加註
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag47 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag47)[3 : length(colnames(flag_person_wide_flag47))]
flag_person_wide_flag47$flag47_r <- NA
for (i in temp){
  flag_person_wide_flag47$flag47_r <- paste(flag_person_wide_flag47$flag47_r, flag_person_wide_flag47[[i]], sep = " ")
}
flag_person_wide_flag47$flag47_r <- gsub("NA ", replacement="", flag_person_wide_flag47$flag47_r)
flag_person_wide_flag47$flag47_r <- gsub(" NA", replacement="", flag_person_wide_flag47$flag47_r)

#產生檢誤報告文字
flag47_temp <- flag_person_wide_flag47 %>%
  group_by(organization_id) %>%
  mutate(flag47_txt = paste(source, "需核對「服務身分別」：", flag47_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag47_txt)) %>%
  distinct(organization_id, flag47_txt)

#根據organization_id，展開成寬資料(wide)
flag47 <- flag47_temp %>%
  dcast(organization_id ~ flag47_txt, value.var = "flag47_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag47)[2 : length(colnames(flag47))]
flag47$flag47 <- NA
for (i in temp){
  flag47$flag47 <- paste(flag47$flag47, flag47[[i]], sep = "； ")
}
flag47$flag47 <- gsub("NA； ", replacement="", flag47$flag47)
flag47$flag47 <- gsub("； NA", replacement="", flag47$flag47)

#產生檢誤報告文字
flag47 <- flag47 %>%
  subset(select = c(organization_id, flag47)) %>%
  distinct(organization_id, flag47) %>%
  mutate(flag47 = paste(flag47, "（請依實際情況並按欄位說明修正）", sep = ""))
}else{
#偵測flag47是否存在。若不存在，則產生NA行
if('flag47' %in% ls()){
  print("flag47")
}else{
  flag47 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag47$flag47 <- ""
}
}
# flag48: 1. 職務名稱與兼任行政職職稱(一)，兩者不應填相同職稱。2. 兼任行政職職稱(一)~(三)，三者不應填相同職稱。-------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$err_admintitle0  <- paste(flag_person$adminunit0, flag_person$admintitle0, sep = "")
flag_person$err_admintitle1  <- paste(flag_person$adminunit1, flag_person$admintitle1, sep = "")
flag_person$err_admintitle2  <- paste(flag_person$adminunit2, flag_person$admintitle2, sep = "")
flag_person$err_admintitle3  <- paste(flag_person$adminunit3, flag_person$admintitle3, sep = "")

#職務名稱與兼任行政職職稱不合理處
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == flag_person$err_admintitle1, 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == "NN" & flag_person$err_admintitle1 == "NN", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == flag_person$err_admintitle2, 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == "NN" & flag_person$err_admintitle2 == "NN", 0, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == flag_person$err_admintitle3, 1, flag_person$err_flag)
flag_person$err_flag <- if_else(flag_person$err_admintitle0 == "NN" & flag_person$err_admintitle3 == "NN", 0, flag_person$err_flag)
flag_person$err_flag <- if_else((flag_person$err_admintitle1 == flag_person$err_admintitle2) & flag_person$err_admintitle1 != "NN", 1, flag_person$err_flag)
flag_person$err_flag <- if_else((flag_person$err_admintitle1 == flag_person$err_admintitle3) & flag_person$err_admintitle1 != "NN", 1, flag_person$err_flag)
flag_person$err_flag <- if_else((flag_person$err_admintitle2 == flag_person$err_admintitle3) & flag_person$err_admintitle2 != "NN", 1, flag_person$err_flag)

#加註姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag48 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag48)[3 : length(colnames(flag_person_wide_flag48))]
flag_person_wide_flag48$flag48_r <- NA
for (i in temp){
  flag_person_wide_flag48$flag48_r <- paste(flag_person_wide_flag48$flag48_r, flag_person_wide_flag48[[i]], sep = " ")
}
flag_person_wide_flag48$flag48_r <- gsub("NA ", replacement="", flag_person_wide_flag48$flag48_r)
flag_person_wide_flag48$flag48_r <- gsub(" NA", replacement="", flag_person_wide_flag48$flag48_r)

#產生檢誤報告文字
flag48_temp <- flag_person_wide_flag48 %>%
  mutate(flag48_txt = 
    case_when(
      source == "教員資料表" ~ paste(source, "需核對「服務身分別」與「兼任行政職職稱(一)」：", flag48_r, sep = ""),
      source == "職員(工)資料表" ~ paste(source, "「職務名稱」與「兼任行政職職稱」重複：", flag48_r, sep = "")
    )) %>%
  group_by(organization_id) %>%
  subset(select = c(organization_id, flag48_txt)) %>%
  distinct(organization_id, flag48_txt)

#根據organization_id，展開成寬資料(wide)
flag48 <- flag48_temp %>%
  dcast(organization_id ~ flag48_txt, value.var = "flag48_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag48)[2 : length(colnames(flag48))]
flag48$flag48 <- NA
for (i in temp){
  flag48$flag48 <- paste(flag48$flag48, flag48[[i]], sep = "； ")
}
flag48$flag48 <- gsub("NA； ", replacement="", flag48$flag48)
flag48$flag48 <- gsub("； NA", replacement="", flag48$flag48)

#產生檢誤報告文字
flag48 <- flag48 %>%
  subset(select = c(organization_id, flag48)) %>%
  distinct(organization_id, flag48) %>%
  mutate(flag48 = paste(flag48, "（以上人員之專職工作職稱請填入『職務名稱』，非『兼任行政職職稱』。併請確認以上人員除本職職務外，是否再兼任其他職務）", sep = ""))
}else{
#偵測flag48是否存在。若不存在，則產生NA行
if('flag48' %in% ls()){
  print("flag48")
}else{
  flag48 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag48$flag48 <- ""
}
}
# flag49: 1.	職員(工)的「職務名稱」不應填N（全型或半型皆不行）。-------------------------------------------------------------------
# 2. 職員(工)的「服務單位」不應填N（全型或半型皆不行），且應入填入對應職稱的學校內部單位。
flag_person <- drev_person_1

#標記職務名稱、服務單位為N或非學校內部單位
flag_person$err_adm1 <- 1
flag_person$err_adm1 <- if_else(grepl("組", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("室", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("科", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("中心", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("部", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("辦公室", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("館", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("處", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("部", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(grepl("^社區大學$", flag_person$adminunit0), 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "", 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "董事會", 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "實習農場", 0, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "NA", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "n", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "N", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "Ｎ", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "國教署", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "y", 1, flag_person$err_adm1)
flag_person$err_adm1 <- if_else(flag_person$adminunit0 == "Y", 1, flag_person$err_adm1)

flag_person$err_adm2 <- 0
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "NA", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "N", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "Ｎ", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "n", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "Y", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(flag_person$admintitle0 == "y", 1, flag_person$err_adm2)
flag_person$err_adm2 <- if_else(grepl("Ｎ", flag_person$admintitle0), 1, flag_person$err_adm2)

flag_person$err_flag <- flag_person$err_adm1 + flag_person$err_adm2
flag_person$err_adm <- 0
flag_person$err_adm <- if_else(flag_person$err_flag != 0 & flag_person$source == "職員(工)資料表", 1, flag_person$err_adm)

#加註
flag_person$name <- paste(flag_person$name, "（", sep = "")
flag_person$name <- if_else(flag_person$err_adm2 != 0, paste(flag_person$name, "職務名稱：", flag_person$admintitle0, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adm1 != 0, paste(flag_person$name, "服務單位：", flag_person$adminunit0, "；", sep = ""), flag_person$name)
flag_person$name <- paste(flag_person$name, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)


flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_adm == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_adm == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag49 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_adm)) %>%
  subset(err_adm == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag49)[3 : length(colnames(flag_person_wide_flag49))]
flag_person_wide_flag49$flag49_r <- NA
for (i in temp){
  flag_person_wide_flag49$flag49_r <- paste(flag_person_wide_flag49$flag49_r, flag_person_wide_flag49[[i]], sep = " ")
}
flag_person_wide_flag49$flag49_r <- gsub("NA ", replacement="", flag_person_wide_flag49$flag49_r)
flag_person_wide_flag49$flag49_r <- gsub(" NA", replacement="", flag_person_wide_flag49$flag49_r)

#產生檢誤報告文字
flag49_temp <- flag_person_wide_flag49 %>%
  group_by(organization_id) %>%
  mutate(flag49_txt = paste(source, "：", flag49_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag49_txt)) %>%
  distinct(organization_id, flag49_txt)

#根據organization_id，展開成寬資料(wide)
flag49 <- flag49_temp %>%
  dcast(organization_id ~ flag49_txt, value.var = "flag49_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag49)[2 : length(colnames(flag49))]
flag49$flag49 <- NA
for (i in temp){
  flag49$flag49 <- paste(flag49$flag49, flag49[[i]], sep = "； ")
}
flag49$flag49 <- gsub("NA； ", replacement="", flag49$flag49)
flag49$flag49 <- gsub("； NA", replacement="", flag49$flag49)

#產生檢誤報告文字
flag49 <- flag49 %>%
  subset(select = c(organization_id, flag49)) %>%
  distinct(organization_id, flag49) %>%
  mutate(flag49 = paste(flag49, "（請確認『職務名稱』、『服務單位』）", sep = ""))
}else{
#偵測flag49是否存在。若不存在，則產生NA行
if('flag49' %in% ls()){
  print("flag49")
}else{
  flag49 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag49$flag49 <- ""
}
}
# flag50: 留職停薪原因為「應徵入伍留職停薪」、「奉派協助友邦留職停薪」、「育嬰留職停薪」、「侍親留職停薪」、「依親留職停薪」、「出國進修或研究留職停薪」、「易服勞役留職停薪」、「延長留職停薪」、「照護配偶或子女留職停薪」、「國內外進修期滿延長留職停薪」、「延長病假期滿留職停薪」、「因公傷病公假期滿留職停薪」、「留職停薪/停聘」、「其他情事留職停薪」，在借調類別應填寫N。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$brtype <- if_else(flag_person$brtype == "NA", "N", flag_person$brtype)

#留職停薪原因不合理處
flag_person$err_lev <- 0
flag_person$err_lev <- if_else(flag_person$levpay %in% c("應徵入伍留職停薪", 
                                                         "奉派協助友邦留職停薪", 
                                                         "育嬰留職停薪", 
                                                         "侍親留職停薪", 
                                                         "依親留職停薪", 
                                                         "出國進修或研究留職停薪", 
                                                         "易服勞役留職停薪", 
                                                         "延長留職停薪", 
                                                         "易服勞役留職停薪", 
                                                         "照護配偶或子女留職停薪", 
                                                         "國內外進修期滿延長留職停薪", 
                                                         "延長病假期滿留職停薪", 
                                                         "留職停薪/停聘", 
                                                         "其他情事留職停薪") 
                               & flag_person$brtype != "N", 1, flag_person$err_lev)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_lev == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_lev == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag50 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_lev)) %>%
  subset(err_lev == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag50)[3 : length(colnames(flag_person_wide_flag50))]
flag_person_wide_flag50$flag50_r <- NA
for (i in temp){
  flag_person_wide_flag50$flag50_r <- paste(flag_person_wide_flag50$flag50_r, flag_person_wide_flag50[[i]], sep = " ")
}
flag_person_wide_flag50$flag50_r <- gsub("NA ", replacement="", flag_person_wide_flag50$flag50_r)
flag_person_wide_flag50$flag50_r <- gsub(" NA", replacement="", flag_person_wide_flag50$flag50_r)

#產生檢誤報告文字
flag50_temp <- flag_person_wide_flag50 %>%
  group_by(organization_id) %>%
  mutate(flag50_txt = paste(source, "需核對「留職停薪原因」與「借調類別」：", flag50_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag50_txt)) %>%
  distinct(organization_id, flag50_txt)

#根據organization_id，展開成寬資料(wide)
flag50 <- flag50_temp %>%
  dcast(organization_id ~ flag50_txt, value.var = "flag50_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag50)[2 : length(colnames(flag50))]
flag50$flag50 <- NA
for (i in temp){
  flag50$flag50 <- paste(flag50$flag50, flag50[[i]], sep = "； ")
}
flag50$flag50 <- gsub("NA； ", replacement="", flag50$flag50)
flag50$flag50 <- gsub("； NA", replacement="", flag50$flag50)

#產生檢誤報告文字
flag50 <- flag50 %>%
  subset(select = c(organization_id, flag50)) %>%
  distinct(organization_id, flag50) %>%
  mutate(flag50 = paste(flag50, "", sep = ""))
}else{
#偵測flag50是否存在。若不存在，則產生NA行
if('flag50' %in% ls()){
  print("flag50")
}else{
  flag50 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag50$flag50 <- ""
}
}
# flag51: 原則上，「留職停薪原因」與「借調類別」填寫應相符:1.	借調公民營事業機構留職停薪?借調至公民營事業機構 2.	借調行政法人機關留職停薪?借調至行政法人機關 3.借調法定實驗學校留職停薪?借調至法定實驗學校-------------------------------------------------------------------
flag_person <- drev_person_1

#「留職停薪原因」與「借調類別」不合理處
flag_person$err_lev <- 0
flag_person$err_lev <- if_else(flag_person$brtype == "借調至公民營事業機構"  & flag_person$levpay != "借調公民營事業機構留職停薪", 1, flag_person$err_lev)
flag_person$err_lev <- if_else(flag_person$brtype == "借調至行政法人機關"  & flag_person$levpay != "借調行政法人機關留職停薪", 1, flag_person$err_lev)
flag_person$err_lev <- if_else(flag_person$brtype == "借調至法定實驗學校"  & flag_person$levpay != "借調法定實驗學校留職停薪", 1, flag_person$err_lev)

flag_person$err_lev <- if_else(flag_person$brtype != "借調至公民營事業機構"  & flag_person$levpay == "借調公民營事業機構留職停薪", 1, flag_person$err_lev)
flag_person$err_lev <- if_else(flag_person$brtype != "借調至行政法人機關"  & flag_person$levpay == "借調行政法人機關留職停薪", 1, flag_person$err_lev)
flag_person$err_lev <- if_else(flag_person$brtype != "借調至法定實驗學校"  & flag_person$levpay == "借調法定實驗學校留職停薪", 1, flag_person$err_lev)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_lev == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_lev == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag51 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_lev)) %>%
  subset(err_lev == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag51)[3 : length(colnames(flag_person_wide_flag51))]
flag_person_wide_flag51$flag51_r <- NA
for (i in temp){
  flag_person_wide_flag51$flag51_r <- paste(flag_person_wide_flag51$flag51_r, flag_person_wide_flag51[[i]], sep = " ")
}
flag_person_wide_flag51$flag51_r <- gsub("NA ", replacement="", flag_person_wide_flag51$flag51_r)
flag_person_wide_flag51$flag51_r <- gsub(" NA", replacement="", flag_person_wide_flag51$flag51_r)

#產生檢誤報告文字
flag51_temp <- flag_person_wide_flag51 %>%
  group_by(organization_id) %>%
  mutate(flag51_txt = paste(source, "需核對「留職停薪原因」與「借調類別」：", flag51_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag51_txt)) %>%
  distinct(organization_id, flag51_txt)

#根據organization_id，展開成寬資料(wide)
flag51 <- flag51_temp %>%
  dcast(organization_id ~ flag51_txt, value.var = "flag51_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag51)[2 : length(colnames(flag51))]
flag51$flag51 <- NA
for (i in temp){
  flag51$flag51 <- paste(flag51$flag51, flag51[[i]], sep = "； ")
}
flag51$flag51 <- gsub("NA； ", replacement="", flag51$flag51)
flag51$flag51 <- gsub("； NA", replacement="", flag51$flag51)

#產生檢誤報告文字
flag51 <- flag51 %>%
  subset(select = c(organization_id, flag51)) %>%
  distinct(organization_id, flag51) %>%
  mutate(flag51 = paste(flag51, "", sep = ""))
}else{
#偵測flag51是否存在。若不存在，則產生NA行
if('flag51' %in% ls()){
  print("flag51")
}else{
  flag51 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag51$flag51 <- ""
}
}
# flag52: 留職停薪原因若填寫「應徵入伍留職停薪」、「奉派協助友邦留職停薪」、「育嬰留職停薪」、「侍親留職停薪」、「依親留職停薪」、「出國進修或研究留職停薪」、「易服勞役留職停薪」、「延長留職停薪」、「照護配偶或子女留職停薪」、「國內外進修期滿延長留職停薪」、「延長病假期滿留職停薪」、「因公傷病公假期滿留職停薪」、「留職停薪/停聘」、「其他情事留職停薪」、「借調公務機關留職停薪」、「借調公民營事業機構留職停薪」、「借調行政法人機關留職停薪」、「借調法定實驗學校留職停薪」，在商借類別應填寫N。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$levpay <- if_else(flag_person$levpay == "NA", "N", flag_person$levpay)
flag_person$negle <- if_else(flag_person$negle == "NA", "N", flag_person$negle)

#「留職停薪原因」、「商借類別」不合理處
flag_person$err_lev <- 0
flag_person$err_lev <- if_else(flag_person$levpay != "N"  & flag_person$negle != "N" & flag_person$source == "教員資料表", 1, flag_person$err_lev)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_lev == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_lev == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag52 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_lev)) %>%
  subset(err_lev == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag52)[3 : length(colnames(flag_person_wide_flag52))]
flag_person_wide_flag52$flag52_r <- NA
for (i in temp){
  flag_person_wide_flag52$flag52_r <- paste(flag_person_wide_flag52$flag52_r, flag_person_wide_flag52[[i]], sep = " ")
}
flag_person_wide_flag52$flag52_r <- gsub("NA ", replacement="", flag_person_wide_flag52$flag52_r)
flag_person_wide_flag52$flag52_r <- gsub(" NA", replacement="", flag_person_wide_flag52$flag52_r)

#產生檢誤報告文字
flag52_temp <- flag_person_wide_flag52 %>%
  group_by(organization_id) %>%
  mutate(flag52_txt = paste(source, "需核對「留職停薪原因」與「商借類別」：", flag52_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag52_txt)) %>%
  distinct(organization_id, flag52_txt)

#根據organization_id，展開成寬資料(wide)
flag52 <- flag52_temp %>%
  dcast(organization_id ~ flag52_txt, value.var = "flag52_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag52)[2 : length(colnames(flag52))]
flag52$flag52 <- NA
for (i in temp){
  flag52$flag52 <- paste(flag52$flag52, flag52[[i]], sep = "； ")
}
flag52$flag52 <- gsub("NA； ", replacement="", flag52$flag52)
flag52$flag52 <- gsub("； NA", replacement="", flag52$flag52)

#產生檢誤報告文字
flag52 <- flag52 %>%
  subset(select = c(organization_id, flag52)) %>%
  distinct(organization_id, flag52) %>%
  mutate(flag52 = paste(flag52, "", sep = ""))
}else{
#偵測flag52是否存在。若不存在，則產生NA行
if('flag52' %in% ls()){
  print("flag52")
}else{
  flag52 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag52$flag52 <- ""
}
}
# flag57: 學歷資料各學位別畢業學校國別/校名/科系所之（一）與（二）內容不應相同，請依學位取得實際情況修正。-------------------------------------------------------------------
flag_person <- drev_person_1

#「留職停薪原因」與「借調類別」不合理處
flag_person$err_degree <- 0
flag_person$err_degree <- if_else((flag_person$ddegreen1 == flag_person$ddegreen2 & flag_person$ddegreen1 != "N") & (flag_person$ddegreeu1 == flag_person$ddegreeu2 & flag_person$ddegreeu1 != "N") & (flag_person$ddegreeg1 == flag_person$ddegreeg2 & flag_person$ddegreeg1 != "N"), 1, flag_person$err_degree)
flag_person$err_degree <- if_else((flag_person$mdegreen1 == flag_person$mdegreen2 & flag_person$mdegreen1 != "N") & (flag_person$mdegreeu1 == flag_person$ddegreeu2 & flag_person$mdegreeu1 != "N") & (flag_person$mdegreeg1 == flag_person$ddegreeg2 & flag_person$mdegreeg1 != "N"), 1, flag_person$err_degree)
flag_person$err_degree <- if_else((flag_person$bdegreen1 == flag_person$bdegreen2 & flag_person$bdegreen1 != "N") & (flag_person$bdegreeu1 == flag_person$bdegreeu2 & flag_person$bdegreeu1 != "N") & (flag_person$bdegreeg1 == flag_person$bdegreeg2 & flag_person$bdegreeg1 != "N"), 1, flag_person$err_degree)
flag_person$err_degree <- if_else((flag_person$adegreen1 == flag_person$adegreen2 & flag_person$adegreen1 != "N") & (flag_person$adegreeu1 == flag_person$adegreeu2 & flag_person$adegreeu1 != "N") & (flag_person$adegreeg1 == flag_person$adegreeg2 & flag_person$adegreeg1 != "N"), 1, flag_person$err_degree)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_degree == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_degree == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag57 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_degree)) %>%
  subset(err_degree == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag57)[3 : length(colnames(flag_person_wide_flag57))]
flag_person_wide_flag57$flag57_r <- NA
for (i in temp){
  flag_person_wide_flag57$flag57_r <- paste(flag_person_wide_flag57$flag57_r, flag_person_wide_flag57[[i]], sep = " ")
}
flag_person_wide_flag57$flag57_r <- gsub("NA ", replacement="", flag_person_wide_flag57$flag57_r)
flag_person_wide_flag57$flag57_r <- gsub(" NA", replacement="", flag_person_wide_flag57$flag57_r)

#產生檢誤報告文字
flag57_temp <- flag_person_wide_flag57 %>%
  group_by(organization_id) %>%
  mutate(flag57_txt = paste("請檢視修正學歷資訊內容：", source, "：", flag57_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag57_txt)) %>%
  distinct(organization_id, flag57_txt)

#根據organization_id，展開成寬資料(wide)
flag57 <- flag57_temp %>%
  dcast(organization_id ~ flag57_txt, value.var = "flag57_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag57)[2 : length(colnames(flag57))]
flag57$flag57 <- NA
for (i in temp){
  flag57$flag57 <- paste(flag57$flag57, flag57[[i]], sep = "； ")
}
flag57$flag57 <- gsub("NA； ", replacement="", flag57$flag57)
flag57$flag57 <- gsub("； NA", replacement="", flag57$flag57)

#產生檢誤報告文字
flag57 <- flag57 %>%
  subset(select = c(organization_id, flag57)) %>%
  distinct(organization_id, flag57) %>%
  mutate(flag57 = paste(flag57, "", sep = ""))
}else{
#偵測flag57是否存在。若不存在，則產生NA行
if('flag57' %in% ls()){
  print("flag57")
}else{
  flag57 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag57$flag57 <- ""
}
}
# flag59: 校長之聘任類別需為「專任」。-------------------------------------------------------------------
flag_person <- drev_person_1

#校長之聘任類別不為專任 不合理
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$sertype == "校長" & flag_person$emptype != "專任", 1, flag_person$err_flag)
#師大附中及高師大附中校長為兼任
flag_person$err_flag <- if_else(flag_person$organization_id == "330301" | flag_person$organization_id == "580301", 0, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag59 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag59)[3 : length(colnames(flag_person_wide_flag59))]
flag_person_wide_flag59$flag59_r <- NA
for (i in temp){
  flag_person_wide_flag59$flag59_r <- paste(flag_person_wide_flag59$flag59_r, flag_person_wide_flag59[[i]], sep = " ")
}
flag_person_wide_flag59$flag59_r <- gsub("NA ", replacement="", flag_person_wide_flag59$flag59_r)
flag_person_wide_flag59$flag59_r <- gsub(" NA", replacement="", flag_person_wide_flag59$flag59_r)

#產生檢誤報告文字
flag59_temp <- flag_person_wide_flag59 %>%
  group_by(organization_id) %>%
  mutate(flag59_txt = paste("校長之聘任類別需為「專任」。", sep = ""), "") %>%
  subset(select = c(organization_id, flag59_txt)) %>%
  distinct(organization_id, flag59_txt)

#根據organization_id，展開成寬資料(wide)
flag59 <- flag59_temp %>%
  dcast(organization_id ~ flag59_txt, value.var = "flag59_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag59)[2 : length(colnames(flag59))]
flag59$flag59 <- NA
for (i in temp){
  flag59$flag59 <- paste(flag59$flag59, flag59[[i]], sep = "； ")
}
flag59$flag59 <- gsub("NA； ", replacement="", flag59$flag59)
flag59$flag59 <- gsub("； NA", replacement="", flag59$flag59)

#產生檢誤報告文字
flag59 <- flag59 %>%
  subset(select = c(organization_id, flag59)) %>%
  distinct(organization_id, flag59) %>%
  mutate(flag59 = paste(flag59, "", sep = ""))
}else{
#偵測flag59是否存在。若不存在，則產生NA行
if('flag59' %in% ls()){
  print("flag59")
}else{
  flag59 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag59$flag59 <- ""
}
}
# flag62: 職務名稱及兼任行政職職稱（一）～（三）資料內容是否完整正確。-------------------------------------------------------------------
#如：1.	職務名稱及兼任行政職職稱（一）～（三）填入非職稱內容。
#2.	服務單位及兼任行政職服務單位（一）～（三）填入非服務單位內容。
#3.	校長、教官、主任教官屬於教員，故應填至教員資料表。
#職員工的「職務名稱」不應有教師、老師等非行政工作之名稱。
flag_person <- drev_person_1

#職務名稱
flag_person$err_admintitle0 <- 1
flag_person$err_admintitle0 <- if_else(grepl("主任$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("佐理員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("助理$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("人員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("助理員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("技士", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("技工", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("技佐", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("防護員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("組長$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("組員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("管理員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("管理師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("輔導員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("工友$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("職工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約僱", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約聘", flag_person$admintitle0), 0, flag_person$err_admintitle0)
#不可只填約僱 約雇 約聘 約聘僱 約聘
flag_person$err_admintitle0 <- if_else(grepl("^約僱$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約雇$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約聘$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約聘僱$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^約聘$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("書記$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("幹事", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^學務創新", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("創新人力", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("營養師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^職輔員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("護士$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("護理師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^均質化承辦人$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^均職化承辦人$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^優質化協辦人$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("校安$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("心理師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("技術員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("職輔員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("廚工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("編制外行政人力$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("司機$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("秘書$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("祕書$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("???書$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("舍監$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("辦事員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("事務員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("職務代理$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("職代$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("職務代理人$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("救生員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("值機員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("監督$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("三副$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("社工師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("校護$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("專員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("雇員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("僱員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^充實行政人力$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("1", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("工讀生$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("工讀$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("警衛$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^實習餐廳經理$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("清潔員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^清潔$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("佐理$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^會計員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^水電$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^總機$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^園藝$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("電工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^木工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^守衛$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("校長$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^副校長$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("館員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^出納$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("庶務$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("環保$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("體衛$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^書院Coach$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("執行長$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("顧問$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^助教$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^督導$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("教師$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("老師$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("導師$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("教學支援人員$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^董事長$", flag_person$admintitle0), 1, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("指導員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("補充行政人力$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^學創人力$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("書記\\(控障-公務人員\\)$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^校警$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^專任行政人力$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("安心上工", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("護理員", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("工程師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("設計師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("駕駛", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^網管$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("守衛$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("廚師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("經理$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("技術士$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("校工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("門衛$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^廚房幫廚$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("保全", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("人事員$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("主廚$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("教練$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("館長$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^臨時工$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^監廚$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^牧師$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
#光禾華德福才可有以下職稱：總務、學務、教務、輔導、人事、國中部行政、高中部行政、會計
flag_person$err_admintitle0 <- if_else(grepl("^國中部行政$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^高中部行政$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^總務$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^學務$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^教務$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^輔導$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^人事$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^會計$", flag_person$admintitle0) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle0)
#東方工商才可有以下職稱：職員
flag_person$err_admintitle0 <- if_else(grepl("^職員$", flag_person$admintitle0) & flag_person$organization_id == "331402", 0, flag_person$err_admintitle0)
#仁義高中才可有以下職稱：會計
flag_person$err_admintitle0 <- if_else(grepl("^會計$", flag_person$admintitle0) & flag_person$organization_id == "201309", 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(flag_person$source == 1, 0, flag_person$err_admintitle0)
#運動教練已在flag34檢查
flag_person$err_admintitle0 <- if_else(grepl("教練$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
#教官已在flag15檢查
flag_person$err_admintitle0 <- if_else(grepl("教官$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
#N或NA已在flag49檢查
flag_person$err_admintitle0 <- if_else(grepl("^N$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
flag_person$err_admintitle0 <- if_else(grepl("^NA$", flag_person$admintitle0), 0, flag_person$err_admintitle0)
#私立光復高中(181305)才可有以下職稱：駐廠(學校稱呼他為"駐廠老師"，但他沒有授課，也不算老師，所以職稱就改為"駐廠")
flag_person$err_admintitle0 <- if_else(grepl("^駐廠$", flag_person$admintitle0) & flag_person$organization_id == "181305", 0, flag_person$err_admintitle0)


#服務單位
flag_person$err_adminunit0 <- 1
flag_person$err_adminunit0 <- if_else(grepl("^人事室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^主計室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^校長室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^副校長室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^特教辦公室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("秘書室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("祕書室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("秘書處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("祕書處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^小學部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國小部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國中部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^中學部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國教署$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教官室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教官室\\(軍訓室\\)$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教務處", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^進修部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^進修學校$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^圖書館$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^圖書室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實習處", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實習室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實習農場$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實習輔導處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^輔導室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("輔導處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^學生事務處", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^學務處", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^總務處", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^雙語部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^專案辦公室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^軍訓室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^會計室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^會計部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^資訊室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^董事會$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("中心$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("研究發展處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^保健室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^招生處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^公關室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^農場經營$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^藝文中心", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("科$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("1", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("組$", flag_person$adminunit0) & (grepl("*處*", flag_person$adminunit0) | grepl("*中心*", flag_person$adminunit0) | grepl("*部*", flag_person$adminunit0) | grepl("*室*", flag_person$adminunit0) | grepl("*館*", flag_person$adminunit0)), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國中部教務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^高中部教務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^中學部教務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際部教務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^中學部學務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("校區校長室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^圖資室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^圖資處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實習就業處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^總務室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^社區大學$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際教育處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^研發處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^資訊處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^實輔處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^住校處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^發展事務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^家具設計發展處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^研發室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^圖資室兼技術交流處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教育推廣處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^學輔處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^顧問室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^研究發展室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^小學部籌備處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^綜合高中$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^技術交流處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("實驗室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^資源班$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^外語部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^外語處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^研發部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際事務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^招生辦公室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("國際處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^電腦室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^招生部$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^宿舍處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^人文室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("服務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^員生社$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教學資源中心處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^校務發展室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^校牧室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^宗輔室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^油印室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^公共事務室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("辦事處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^生命教育室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教學研究室$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國際暨建教處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^外語中心處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("語文中心$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^國小部總務處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^外語教學處$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
#立志高中才有"高國中部"
flag_person$err_adminunit0 <- if_else(grepl("^高國中部$", flag_person$adminunit0) & flag_person$organization_id == "551301", 0, flag_person$err_adminunit0)
#光禾華德福才可有以下服務單位：國中部日間部、高中部日間部
flag_person$err_adminunit0 <- if_else(grepl("^國中部日間部$", flag_person$adminunit0) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^高中部日間部$", flag_person$adminunit0) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit0)
#N或NA已在flag49檢查
flag_person$err_adminunit0 <- if_else(grepl("^N$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^NA$", flag_person$adminunit0), 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(flag_person$source == 1, 0, flag_person$err_adminunit0)
#台北市育達高中 雲林縣維多利亞實驗高中有"教導處"
flag_person$err_adminunit0 <- if_else(grepl("^教導處$", flag_person$adminunit0) & flag_person$organization_id == "311401", 0, flag_person$err_adminunit0)
flag_person$err_adminunit0 <- if_else(grepl("^教導處$", flag_person$adminunit0) & flag_person$organization_id == "091320", 0, flag_person$err_adminunit0)
#磐石高中有"國中部雙語班"
flag_person$err_adminunit0 <- if_else(grepl("^國中部雙語班$", flag_person$adminunit0) & flag_person$organization_id == "181307", 0, flag_person$err_adminunit0)
#私立光復高中(181305)有"完全中學部"
flag_person$err_adminunit0 <- if_else(grepl("^完全中學部$", flag_person$adminunit0) & flag_person$organization_id == "181305", 0, flag_person$err_adminunit0)

#兼任行政職職稱（一）
flag_person$err_admintitle1 <- 1
flag_person$err_admintitle1 <- if_else(grepl("主任$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("秘書$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("組長$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("組員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^副校長$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^均質化承辦人$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^均職化承辦人$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^優質化協辦人$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("校安$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("心理師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("技術員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("防護員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("人員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("職輔員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("廚工$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("營養師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("編制外行政人力$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("司機$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("秘書$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("祕書$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("舍監$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("辦事員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("幹事$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("職務代理$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("職代$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("職務代理人$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("救生員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("值機員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("監督$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("三副$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("社工師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("助理$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("專員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("政風$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("1", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^N$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("輔導員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^警衛$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^實習餐廳經理$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("管理師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("清潔員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("佐理$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("技佐$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^會計員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("管理員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^書記$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("佐理員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("館員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("科主席$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("護理師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("助理員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^助教$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("庶務$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("文書$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^電競專案教練$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^出納$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^助教$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^督導$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("訓育業務$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("指導員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("駕駛", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^網管$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("守衛$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("廚師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("經理$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("技術士$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("校工$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("門衛$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^廚房幫廚$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^臨時約聘助理(計時)$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("保全", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("人事員$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("主廚$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("教練$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("館長$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("技士$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("技工$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^監廚$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
#光禾華德福才可有以下職稱：總務、學務、教務、輔導、人事、國中部行政、高中部行政、會計
flag_person$err_admintitle1 <- if_else(grepl("^國中部行政$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^高中部行政$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^總務$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^學務$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^教務$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^輔導$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^人事$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^會計$", flag_person$admintitle1) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^校長$", flag_person$admintitle1), 1, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("教官$", flag_person$admintitle1), 1, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("教師$", flag_person$admintitle1), 1, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("運動教練$", flag_person$admintitle1), 1, flag_person$err_admintitle1)
flag_person$err_admintitle1 <- if_else(grepl("^董事長$", flag_person$admintitle1), 1, flag_person$err_admintitle1)
#校長已在flag15檢查
flag_person$err_admintitle1 <- if_else(grepl("^校長$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
#導師已在flag15檢查
flag_person$err_admintitle1 <- if_else(grepl("導師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
#教師已在flag15檢查
flag_person$err_admintitle1 <- if_else(grepl("教師$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
#教官已在flag15檢查
flag_person$err_admintitle1 <- if_else(grepl("教官$", flag_person$admintitle1), 0, flag_person$err_admintitle1)
#私立立仁高中(201314)才可有以下職稱：人事
flag_person$err_admintitle1 <- if_else(grepl("^人事$", flag_person$admintitle1) & flag_person$organization_id == "201314", 0, flag_person$err_admintitle1)


#兼任行政職服務單位（一）
flag_person$err_adminunit1 <- 1
flag_person$err_adminunit1 <- if_else(grepl("^校長室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^副校長室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^秘書室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國小部", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^小學部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國中部$", flag_person$adminunit1) | grepl("^國民中學部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^中學部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教官室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教務處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^進修部", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^進修學校$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^資訊室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^圖書館", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^圖書室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^實習處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^實習室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^輔導室", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("輔導處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^學生事務處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^學務處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^總務處", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^雙語部", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^軍訓室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^會計室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^主計室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^資訊室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^董事會$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("中心$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("研究發展處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("人事室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^招生處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^公關室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^農場經營$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^藝文中心", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("科$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("1", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("組$", flag_person$adminunit1) & (grepl("*處*", flag_person$adminunit1) | grepl("*中心*", flag_person$adminunit1) | grepl("*部*", flag_person$adminunit1) | grepl("*室*", flag_person$adminunit1) | grepl("*館*", flag_person$adminunit1)), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^N$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國中部教務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^高中部教務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^中學部教務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際部教務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^中學部學務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("校區校長室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^圖資室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^圖資處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際教育處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^研發處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^資訊處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^實輔處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^家具設計發展處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^研發室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^圖資室兼技術交流處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教育推廣處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^學輔處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^綜合高中$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^技術交流處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^補校$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際交流處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^專案研究室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("分校$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^創發處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^補校教學組$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^補校教務組$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^補校訓育組$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^實驗研究組$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^外語部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^外語處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^研發部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際事務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^招生辦公室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("國際處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^電腦室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^招生部$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^宿舍處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^人文室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("服務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^員生社$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教學資源中心處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^校務發展室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^校牧室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^宗輔室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^油印室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^公共事務室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("辦事處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^生命教育室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教學研究室$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國際暨建教處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^外語中心處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("語文中心$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^國小部總務處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^外語教學處$", flag_person$adminunit1), 0, flag_person$err_adminunit1)
#立志高中才有"高國中部"
flag_person$err_adminunit1 <- if_else(grepl("^高國中部$", flag_person$adminunit1) & flag_person$organization_id == "551301", 0, flag_person$err_adminunit1)
#光禾華德福才可有以下服務單位：國中部日間部、高中部日間部
flag_person$err_adminunit1 <- if_else(grepl("^國中部日間部$", flag_person$adminunit1) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^高中部日間部$", flag_person$adminunit1) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit1)
#磐石高中才有"高中部"
flag_person$err_adminunit1 <- if_else(grepl("^高中部$", flag_person$adminunit1) & flag_person$organization_id == "181307", 0, flag_person$err_adminunit1)
#私立義大國際高中(121320)才有"發展事務處"
flag_person$err_adminunit1 <- if_else(grepl("^發展事務處$", flag_person$adminunit1) & flag_person$organization_id == "121320", 0, flag_person$err_adminunit1)
#天主教道明中學(581302)才有"劍橋國際事務部"
flag_person$err_adminunit1 <- if_else(grepl("^劍橋國際事務部$", flag_person$adminunit1) & flag_person$organization_id == "581302", 0, flag_person$err_adminunit1)
#台北市育達高中 雲林縣維多利亞實驗高中有"教導處"
flag_person$err_adminunit1 <- if_else(grepl("^教導處$", flag_person$adminunit1) & flag_person$organization_id == "311401", 0, flag_person$err_adminunit1)
flag_person$err_adminunit1 <- if_else(grepl("^教導處$", flag_person$adminunit1) & flag_person$organization_id == "091320", 0, flag_person$err_adminunit1)

#兼任行政職職稱（二）
flag_person$err_admintitle2 <- 1
flag_person$err_admintitle2 <- if_else(grepl("主任$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("秘書$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("組長$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("組員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^副校長$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^均質化承辦人$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^均職化承辦人$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^優質化協辦人$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("校安$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("心理師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("技術員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("人員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("職輔員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("廚工$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("營養師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("編制外行政人力$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("司機$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("秘書$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("祕書$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("舍監$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("辦事員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("幹事$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("職務代理$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("職代$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("職務代理人$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("救生員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("值機員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("監督$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("三副$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("社工師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("助理$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("專員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("政風$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("1", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^N$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("輔導員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^警衛$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^實習餐廳經理$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("管理師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("清潔員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("佐理$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("技佐$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^會計員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("管理員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^書記$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("佐理員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("館員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("科主席$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("護理師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("助理員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^助教$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("庶務$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("文書$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^電競專案教練$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^出納$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^助教$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^督導$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("訓育業務$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("指導員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("駕駛", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^網管$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("守衛$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("廚師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("經理$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("技術士$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("校工$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("門衛$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^廚房幫廚$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^臨時約聘助理(計時)$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("保全", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("人事員$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("主廚$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("教練$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("館長$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("技士$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("技工$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^監廚$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
#光禾華德福才可有以下職稱：總務、學務、教務、輔導、人事、國中部行政、高中部行政、會計
flag_person$err_admintitle2 <- if_else(grepl("^國中部行政$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^高中部行政$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^總務$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^學務$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^教務$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^輔導$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^人事$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^會計$", flag_person$admintitle2) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^校長$", flag_person$admintitle2), 1, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("教官$", flag_person$admintitle2), 1, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("教師$", flag_person$admintitle2), 1, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("運動教練$", flag_person$admintitle2), 1, flag_person$err_admintitle2)
flag_person$err_admintitle2 <- if_else(grepl("^董事長$", flag_person$admintitle2), 1, flag_person$err_admintitle2)
#校長已在flag15檢查
flag_person$err_admintitle2 <- if_else(grepl("^校長$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
#導師已在flag15檢查
flag_person$err_admintitle2 <- if_else(grepl("導師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
#教師已在flag15檢查
flag_person$err_admintitle2 <- if_else(grepl("教師$", flag_person$admintitle2), 0, flag_person$err_admintitle2)
#教官已在flag15檢查
flag_person$err_admintitle2 <- if_else(grepl("教官$", flag_person$admintitle2), 0, flag_person$err_admintitle2)


#兼任行政職服務單位（二）
flag_person$err_adminunit2 <- 1
flag_person$err_adminunit2 <- if_else(grepl("^校長室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^副校長室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^秘書室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國小部", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^小學部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國中部$", flag_person$adminunit2) | grepl("^國民中學部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^中學部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教官室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教務處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^進修部", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^進修學校$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^資訊室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^圖書館", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^圖書室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^實習處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^實習室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^輔導室", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("輔導處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^學生事務處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^學務處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^總務處", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^雙語部", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^軍訓室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^會計室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^主計室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^資訊室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^董事會$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("中心$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("研究發展處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("人事室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^招生處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^公關室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^農場經營$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^藝文中心", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("科$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("1", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("組$", flag_person$adminunit2) & (grepl("*處*", flag_person$adminunit2) | grepl("*中心*", flag_person$adminunit2) | grepl("*部*", flag_person$adminunit2) | grepl("*室*", flag_person$adminunit2) | grepl("*館*", flag_person$adminunit2)), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^N$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國中部教務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^高中部教務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^中學部教務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際部教務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^中學部學務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("校區校長室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^圖資室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^圖資處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際教育處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^研發處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^資訊處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^實輔處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^家具設計發展處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^研發室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^圖資室兼技術交流處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教育推廣處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^學輔處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^綜合高中$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^技術交流處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^補校$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際交流處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^專案研究室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("分校$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^創發處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^補校教學組$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^補校教務組$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^補校訓育組$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^實驗研究組$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^外語部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^外語處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^研發部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際事務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^招生辦公室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("國際處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^電腦室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^招生部$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^宿舍處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^人文室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("服務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^員生社$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教學資源中心處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^校務發展室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^校牧室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^宗輔室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^油印室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^公共事務室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("辦事處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^生命教育室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教學研究室$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國際暨建教處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^外語中心處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("語文中心$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^國小部總務處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^外語教學處$", flag_person$adminunit2), 0, flag_person$err_adminunit2)
#立志高中才有"高國中部"
flag_person$err_adminunit2 <- if_else(grepl("^高國中部$", flag_person$adminunit2) & flag_person$organization_id == "551301", 0, flag_person$err_adminunit2)
#光禾華德福才可有以下服務單位：國中部日間部、高中部日間部
flag_person$err_adminunit2 <- if_else(grepl("^國中部日間部$", flag_person$adminunit2) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^高中部日間部$", flag_person$adminunit2) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit2)
#磐石高中才有"高中部"
flag_person$err_adminunit2 <- if_else(grepl("^高中部$", flag_person$adminunit2) & flag_person$organization_id == "181307", 0, flag_person$err_adminunit2)
#台北市育達高中 雲林縣維多利亞實驗高中有"教導處"
flag_person$err_adminunit2 <- if_else(grepl("^教導處$", flag_person$adminunit2) & flag_person$organization_id == "311401", 0, flag_person$err_adminunit2)
flag_person$err_adminunit2 <- if_else(grepl("^教導處$", flag_person$adminunit2) & flag_person$organization_id == "091320", 0, flag_person$err_adminunit2)


#兼任行政職職稱（三）
flag_person$err_admintitle3 <- 1
flag_person$err_admintitle3 <- if_else(grepl("主任$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("秘書$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("組長$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("組員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^副校長$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^均質化承辦人$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^均職化承辦人$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^優質化協辦人$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("校安$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("心理師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("技術員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("人員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("職輔員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("廚工$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("營養師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("編制外行政人力$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("司機$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("秘書$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("祕書$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("舍監$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("辦事員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("幹事$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("職務代理$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("職代$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("職務代理人$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("救生員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("值機員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("監督$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("三副$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("社工師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("助理$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("專員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("政風$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("1", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^N$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("輔導員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^警衛$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^實習餐廳經理$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("管理師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("清潔員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("佐理$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("技佐$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^會計員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("管理員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^書記$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("佐理員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("館員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("科主席$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("護理師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("助理員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^助教$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("庶務$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("文書$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^電競專案教練$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^出納$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^助教$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^督導$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("訓育業務$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("指導員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("駕駛", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^網管$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("守衛$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("廚師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("經理$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("技術士$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("校工$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("門衛$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^廚房幫廚$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^臨時約聘助理(計時)$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("保全", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("人事員$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("主廚$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("教練$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("館長$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("技士$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("技工$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^監廚$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
#光禾華德福才可有以下職稱：總務、學務、教務、輔導、人事、國中部行政、高中部行政、會計
flag_person$err_admintitle3 <- if_else(grepl("^國中部行政$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^高中部行政$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^總務$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^學務$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^教務$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^輔導$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^人事$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^會計$", flag_person$admintitle3) & flag_person$organization_id == "121302", 0, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^校長$", flag_person$admintitle3), 1, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("教官$", flag_person$admintitle3), 1, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("教師$", flag_person$admintitle3), 1, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("運動教練$", flag_person$admintitle3), 1, flag_person$err_admintitle3)
flag_person$err_admintitle3 <- if_else(grepl("^董事長$", flag_person$admintitle3), 1, flag_person$err_admintitle3)
#校長已在flag15檢查
flag_person$err_admintitle3 <- if_else(grepl("^校長$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
#導師已在flag15檢查
flag_person$err_admintitle3 <- if_else(grepl("導師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
#教師已在flag15檢查
flag_person$err_admintitle3 <- if_else(grepl("教師$", flag_person$admintitle3), 0, flag_person$err_admintitle3)
#教官已在flag15檢查
flag_person$err_admintitle3 <- if_else(grepl("教官$", flag_person$admintitle3), 0, flag_person$err_admintitle3)


#兼任行政職服務單位（三）
flag_person$err_adminunit3 <- 1
flag_person$err_adminunit3 <- if_else(grepl("^校長室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^副校長室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^秘書室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國小部", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^小學部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國中部$", flag_person$adminunit3) | grepl("^國民中學部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^中學部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教官室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教務處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^進修部", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^進修學校$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^資訊室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^圖書館", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^圖書室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^實習處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^實習室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^輔導室", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("輔導處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^學生事務處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^學務處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^總務處", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^雙語部", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^軍訓室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^會計室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^主計室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^資訊室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^董事會$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("中心$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("研究發展處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("人事室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^招生處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^公關室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^農場經營$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^藝文中心", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("科$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("1", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("組$", flag_person$adminunit3) & (grepl("*處*", flag_person$adminunit3) | grepl("*中心*", flag_person$adminunit3) | grepl("*部*", flag_person$adminunit3) | grepl("*室*", flag_person$adminunit3) | grepl("*館*", flag_person$adminunit3)), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^N$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國中部教務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^高中部教務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^中學部教務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際部教務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^中學部學務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("校區校長室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^圖資室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^圖資處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際教育處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^研發處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^資訊處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^實輔處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^家具設計發展處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^研發室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^圖資室兼技術交流處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教育推廣處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^學輔處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^綜合高中$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^技術交流處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^補校$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際交流處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^專案研究室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("分校$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^創發處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^補校教學組$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^補校教務組$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^補校訓育組$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^實驗研究組$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^外語部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^外語處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^研發部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際事務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^招生辦公室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("國際處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^電腦室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^招生部$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^宿舍處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^人文室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("服務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^員生社$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教學資源中心處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^校務發展室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^校牧室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^宗輔室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^油印室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^公共事務室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("辦事處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^生命教育室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教學研究室$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國際暨建教處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^外語中心處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("語文中心$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^國小部總務處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^外語教學處$", flag_person$adminunit3), 0, flag_person$err_adminunit3)
#立志高中才有"高國中部"
flag_person$err_adminunit3 <- if_else(grepl("^高國中部$", flag_person$adminunit3) & flag_person$organization_id == "551301", 0, flag_person$err_adminunit3)
#光禾華德福才可有以下服務單位：國中部日間部、高中部日間部
flag_person$err_adminunit3 <- if_else(grepl("^國中部日間部$", flag_person$adminunit3) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^高中部日間部$", flag_person$adminunit3) & flag_person$organization_id == "121302", 0, flag_person$err_adminunit3)
#磐石高中才有"高中部"
flag_person$err_adminunit3 <- if_else(grepl("^高中部$", flag_person$adminunit3) & flag_person$organization_id == "181307", 0, flag_person$err_adminunit3)
#台北市育達高中 雲林縣維多利亞實驗高中有"教導處"
flag_person$err_adminunit3 <- if_else(grepl("^教導處$", flag_person$adminunit3) & flag_person$organization_id == "311401", 0, flag_person$err_adminunit3)
flag_person$err_adminunit3 <- if_else(grepl("^教導處$", flag_person$adminunit3) & flag_person$organization_id == "091320", 0, flag_person$err_adminunit3)

#以下為參考文字
  #教員資料表之各兼任行政職資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如教務處教學組，學生事務處生活輔導組。
  #教員資料表之兼任行政職資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如教務處教學組，學生事務處生活輔導組。
  #職員(工)資料表之各服務單位資料不完整或不正確：請依欄位說明確認並正確填列服務單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如總務處出納組，學生事務處生活輔導組。
  #教員資料表及職員(工)資料表之(兼任)職稱或服務單位資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如教務處教學組，總務處出納組。
  #上述職員(工)資料表中人員，若未再兼任或代理行政職務者，僅須填寫「職務名稱」與「服務單位」，且二級單位名稱請於「服務單位」所填一級單位名稱後面加註。
  #請確認*員之職稱或服務身分別，若確為教師，請將資料填至教員資料表。
  #（職員(工)資料表之服務單位資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位，請敘明一級與二級單位名稱，如學務處體育組，總務處出納組。另請再確認資源班是否為行政單位名稱。）
  #（請確認並正確填列『兼任行政職服務單位』名稱，此欄位不需填入職務名稱。）
  #（若確認*員因故代理校長，請於所代理之行政職職稱、行政職服務單位註記「1」，填報方式如下：
    #兼任行政職職稱(一)：校長1
    #兼任行政職服務單位(一)：校長室1）
  #（請再協助確認*員職務正確完整名稱，職稱與服務單位請依不同欄位分別填寫）  
  #（請依欄位說明，填列蔡員於校內任職之正確職務名稱及服務單位名稱於『職務名稱』及『服務單位』欄位（如屬二級單位者，請敘明一與二級單位名稱）。
    #若蔡員於校內兼任多項行政職務，請分別填列於『兼任行政職職稱』、『兼任行政職服務單位』（一）～（三）欄位。
    #蔡員於本學期若代理行政職務，所代理之行政職稱及其服務單位亦請填寫於 本 兼任行政職職稱及兼任行政職服務單位 欄，並於代理職稱與單位後加註「1」。）



  #人事、會計僅設組長
  #（職員(工)資料表之各服務單位資料不完整或不正確：請依欄位說明確認並正確填列服務單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如總務處出納組，學生事務處生活輔導組。若編制並未設組，請來電告知）

err_title0 <- data.frame(admintitle0 = flag_person$admintitle0, 
                         adminunit0 = flag_person$adminunit0, 
                         organization_id = flag_person$organization_id)
flag_person$err_title0 <- if_else(!err_title0$admintitle0 %in% "N" & err_title0$admintitle0 %in% "組長" & ((!grepl("組$", err_title0$adminunit0) & !grepl("^N$", err_title0$adminunit0)) | (grepl("組$", err_title0$adminunit0) & nchar(err_title0$adminunit0) <= 5)), 1, 0)

err_title1 <- data.frame(admintitle1 = flag_person$admintitle1, 
                         adminunit1 = flag_person$adminunit1, 
                         organization_id = flag_person$organization_id)
flag_person$err_title1 <- if_else(!err_title1$admintitle1 %in% "N" & err_title1$admintitle1 %in% "組長" & ((!grepl("組$", err_title1$adminunit1) & !grepl("^N$", err_title1$adminunit1)) | (grepl("組$", err_title1$adminunit1) & nchar(err_title1$adminunit1) <= 5)), 1, 0)

err_title2 <- data.frame(admintitle2 = flag_person$admintitle2, 
                         adminunit2 = flag_person$adminunit2, 
                         organization_id = flag_person$organization_id)
flag_person$err_title2 <- if_else(!err_title2$admintitle2 %in% "N" & err_title2$admintitle2 %in% "組長" & ((!grepl("組$", err_title2$adminunit2) & !grepl("^N$", err_title2$adminunit2)) | (grepl("組$", err_title2$adminunit2) & nchar(err_title2$adminunit2) <= 5)), 1, 0)

err_title3 <- data.frame(admintitle3 = flag_person$admintitle3, 
                         adminunit3 = flag_person$adminunit3, 
                         organization_id = flag_person$organization_id)
flag_person$err_title3 <- if_else(!err_title3$admintitle3 %in% "N" & err_title3$admintitle3 %in% "組長" & ((!grepl("組$", err_title3$adminunit3) & !grepl("^N$", err_title3$adminunit3)) | (grepl("組$", err_title3$adminunit3) & nchar(err_title3$adminunit3) <= 5)), 1, 0)

flag_person$err_flag_62 <- flag_person$err_admintitle0 + flag_person$err_adminunit0 + flag_person$err_admintitle1 + flag_person$err_adminunit1 + flag_person$err_admintitle2 + flag_person$err_adminunit2 + flag_person$err_admintitle3 + flag_person$err_adminunit3 + flag_person$err_title0 + flag_person$err_title1 + flag_person$err_title2 + flag_person$err_title3

flag_person$err_flag <- if_else(flag_person$err_flag_62 != 0, 1, 0)


#備註文字用
  #err_flag_1: 職稱或服務單位不合理
flag_person$err_flag_1 <- if_else(flag_person$err_admintitle0 != 0 | 
  flag_person$err_adminunit0 != 0 | 
  flag_person$err_admintitle1 != 0 | 
  flag_person$err_adminunit1 != 0 | 
  flag_person$err_admintitle2 != 0 | 
  flag_person$err_adminunit2 != 0 | 
  flag_person$err_admintitle3 != 0 | 
  flag_person$err_adminunit3 != 0, 1, 0)
  #err_flag_2: 職稱為組長，且未填二級單位
flag_person$err_flag_2 <- if_else(flag_person$err_title0 != 0 |                                    flag_person$err_title1 != 0 | 

                                   flag_person$err_title2 != 0 | 
                                   flag_person$err_title3 != 0, 1, 0)
    #err_flag_2_1: 職員工資料表出現err_flag_2
flag_person$err_flag2_1 <- if_else((flag_person$err_title0 != 0 | 
                                    flag_person$err_title1 != 0 | 
                                    flag_person$err_title2 != 0 | 
                                    flag_person$err_title3 != 0 ) & 
                                    flag_person$source == "職員(工)資料表", 1, 0)
    #err_flag_2_2: 教員資料表出現err_flag_2
flag_person$err_flag2_2 <- if_else((flag_person$err_title1 != 0 | 
                                    flag_person$err_title2 != 0 | 
                                    flag_person$err_title3 != 0) & 
                                    flag_person$source == "教員資料表", 1, 0)

#aggregate該校err_flag2_1及err_flag2_2 -> 該校err_flag_2(職稱為組長，且未填二級單位)出現在教員or職員(工)資料表
flag_person_err_flag_detect <- aggregate(cbind(err_flag2_1, err_flag2_2) ~ organization_id, flag_person, sum) %>%
  rename(err_flag2_1_detect = err_flag2_1, err_flag2_2_detect = err_flag2_2)

flag_person <- flag_person %>%
  left_join(flag_person_err_flag_detect, by = "organization_id")
  
#加註
flag_person$name <- paste(flag_person$name, "（", sep = "")
flag_person$name <- if_else(flag_person$err_admintitle0 != 0, paste(flag_person$name, "職務名稱：", flag_person$admintitle0, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adminunit0 != 0, paste(flag_person$name, "服務單位：", flag_person$adminunit0, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_admintitle1 != 0, paste(flag_person$name, "兼任行政職職稱(一)：", flag_person$admintitle1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adminunit1 != 0, paste(flag_person$name, "兼任行政職服務單位(一)：", flag_person$adminunit1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_admintitle2 != 0, paste(flag_person$name, "兼任行政職職稱(二)：", flag_person$admintitle2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adminunit2 != 0, paste(flag_person$name, "兼任行政職服務單位(二)：", flag_person$adminunit2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_admintitle3 != 0, paste(flag_person$name, "兼任行政職職稱(三)：", flag_person$admintitle3, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adminunit3 != 0, paste(flag_person$name, "兼任行政職服務單位(三)：", flag_person$adminunit3, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_title0 != 0, paste(flag_person$name, "服務單位：", flag_person$adminunit0, " ", "職務名稱：", flag_person$admintitle0, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_title1 != 0, paste(flag_person$name, "兼任行政職服務單位(一)：", flag_person$adminunit1, " ", "兼任行政職職稱(一)：", flag_person$admintitle1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_title2 != 0, paste(flag_person$name, "兼任行政職服務單位(二)：", flag_person$adminunit2, " ", "兼任行政職職稱(二)：", flag_person$admintitle2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_title3 != 0, paste(flag_person$name, "兼任行政職服務單位(三)：", flag_person$adminunit3, " ", "兼任行政職職稱(三)：", flag_person$admintitle3, "；", sep = ""), flag_person$name)
flag_person$name <- paste(flag_person$name, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag62_1 <- tryCatch({
    flag_person %>%
      subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag, err_flag_1, err_flag2_1, err_flag2_2, err_flag2_1_detect, err_flag2_2_detect)) %>%
      subset(err_flag_1 == 1) %>%
      dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  }, error = function(e) {
    NULL
  })

if(!is.null(flag_person_wide_flag62_1)){
#合併所有name
temp <- colnames(flag_person_wide_flag62_1)[3 : length(colnames(flag_person_wide_flag62_1))]
flag_person_wide_flag62_1$flag62_1_r <- NA
for (i in temp){
  flag_person_wide_flag62_1$flag62_1_r <- paste(flag_person_wide_flag62_1$flag62_1_r, flag_person_wide_flag62_1[[i]], sep = " ")
}
flag_person_wide_flag62_1$flag62_1_r <- gsub("NA ", replacement="", flag_person_wide_flag62_1$flag62_1_r)
flag_person_wide_flag62_1$flag62_1_r <- gsub(" NA", replacement="", flag_person_wide_flag62_1$flag62_1_r)
flag_person_wide_flag62_1$flag62_1_r <- paste0(flag_person_wide_flag62_1$flag62_1_r, "\n（請再協助確認上述人員職務正確完整名稱）") #若#err_flag_1: 職稱或服務單位不合理，則加註
}else{
  print("flag_person_wide_flag62_1 not exists.")
  rm(flag_person_wide_flag62_1)
}

#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag62_2_1 <- tryCatch({
  flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag, err_flag_1, err_flag2_1, err_flag2_2, err_flag2_1_detect, err_flag2_2_detect)) %>%
    subset(err_flag2_1 == 1 & err_flag2_2_detect == 0) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
}, error = function(e) {
  NULL
})

if(!is.null(flag_person_wide_flag62_2_1)){
#合併所有name
temp <- colnames(flag_person_wide_flag62_2_1)[3 : length(colnames(flag_person_wide_flag62_2_1))]
flag_person_wide_flag62_2_1$flag62_2_1_r <- NA
for (i in temp){
  flag_person_wide_flag62_2_1$flag62_2_1_r <- paste(flag_person_wide_flag62_2_1$flag62_2_1_r, flag_person_wide_flag62_2_1[[i]], sep = " ")
}
flag_person_wide_flag62_2_1$flag62_2_1_r <- gsub("NA ", replacement="", flag_person_wide_flag62_2_1$flag62_2_1_r)
flag_person_wide_flag62_2_1$flag62_2_1_r <- gsub(" NA", replacement="", flag_person_wide_flag62_2_1$flag62_2_1_r)
flag_person_wide_flag62_2_1$flag62_2_1_r <- paste0(flag_person_wide_flag62_2_1$flag62_2_1_r, "\n（職員(工)資料表之各服務單位資料不完整或不正確：請依欄位說明確認並正確填列服務單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如總務處出納組，學生事務處生活輔導組。若編制並未設組，請來電告知。）") #若#err_flag_2_1: 職員工資料表出現err_flag_2，則加註
}else{
  print("flag_person_wide_flag62_2_1 not exists.")
  rm(flag_person_wide_flag62_2_1)
}

#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag62_2_2 <- tryCatch({
  flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag, err_flag_1, err_flag2_1, err_flag2_2, err_flag2_1_detect, err_flag2_2_detect)) %>%
    subset(err_flag2_2 == 1 & err_flag2_1_detect == 0) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
}, error = function(e) {
  NULL
})

if(!is.null(flag_person_wide_flag62_2_2)){
#合併所有name
temp <- colnames(flag_person_wide_flag62_2_2)[3 : length(colnames(flag_person_wide_flag62_2_2))]
flag_person_wide_flag62_2_2$flag62_2_2_r <- NA
for (i in temp){
  flag_person_wide_flag62_2_2$flag62_2_2_r <- paste(flag_person_wide_flag62_2_2$flag62_2_2_r, flag_person_wide_flag62_2_2[[i]], sep = " ")
}
flag_person_wide_flag62_2_2$flag62_2_2_r <- gsub("NA ", replacement="", flag_person_wide_flag62_2_2$flag62_2_2_r)
flag_person_wide_flag62_2_2$flag62_2_2_r <- gsub(" NA", replacement="", flag_person_wide_flag62_2_2$flag62_2_2_r)
flag_person_wide_flag62_2_2$flag62_2_2_r <- paste0(flag_person_wide_flag62_2_2$flag62_2_2_r, "\n（教員資料表之各兼任行政職資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如教務處教學組，學生事務處生活輔導組。若編制並未設組，請來電告知。）") #若err_flag_2_2: 教員資料表出現err_flag_2，則加註
}else{
  print("flag_person_wide_flag62_2_2 not exists.")
  rm(flag_person_wide_flag62_2_2)
}

#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag62_2_3 <- tryCatch({
  flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag, err_flag_1, err_flag2_1, err_flag2_2, err_flag2_1_detect, err_flag2_2_detect)) %>%
    subset((err_flag2_1 == 1 & err_flag2_2_detect != 0) | (err_flag2_1_detect != 0 & err_flag2_2 == 1)) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
}, error = function(e) {
  NULL
})

if(!is.null(flag_person_wide_flag62_2_3)){
#合併所有name
temp <- colnames(flag_person_wide_flag62_2_3)[3 : length(colnames(flag_person_wide_flag62_2_3))]
flag_person_wide_flag62_2_3$flag62_2_3_r <- NA
for (i in temp){
  flag_person_wide_flag62_2_3$flag62_2_3_r <- paste(flag_person_wide_flag62_2_3$flag62_2_3_r, flag_person_wide_flag62_2_3[[i]], sep = " ")
}
flag_person_wide_flag62_2_3$flag62_2_3_r <- gsub("NA ", replacement="", flag_person_wide_flag62_2_3$flag62_2_3_r)
flag_person_wide_flag62_2_3$flag62_2_3_r <- gsub(" NA", replacement="", flag_person_wide_flag62_2_3$flag62_2_3_r)
flag_person_wide_flag62_2_3$flag62_2_3_r <- if_else(flag_person_wide_flag62_2_3$source == "職員(工)資料表", 
  paste0(flag_person_wide_flag62_2_3$flag62_2_3_r, "\n（教員資料表及職員(工)資料表之(兼任)職稱或服務單位資料不完整或不正確：請依欄位說明確認並正確填列行政單位名稱，如為二級單位主管，請敘明一級與二級單位名稱。如教務處教學組，總務處出納組。若編制並未設組，請來電告知。）"),  #若err_flag_2_3: 教員及職員工資料表同時出現err_flag_2，則加註
  flag_person_wide_flag62_2_3$flag62_2_3_r)
}else{
  print("flag_person_wide_flag62_2_3 not exists.")
  rm(flag_person_wide_flag62_2_3)
}

if('flag_person_wide_flag62_1' %in% ls()){ #如果flag_person_wide_flag62_1有建立成功
  print("flag_person_wide_flag62_1 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag62_1 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
  data_source <- c("教員資料表", "職員(工)資料表")
  
  flag_person_wide_flag62_1 <- expand.grid(organization_id = flag_person_wide_flag62_1$organization_id %>% as.character(), 
                                           source = data_source)
  flag_person_wide_flag62_1$flag62_1_r <-  ""
}

if('flag_person_wide_flag62_2_1' %in% ls()){ #如果flag_person_wide_flag62_2_1有建立成功
  print("flag_person_wide_flag62_2_1 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag62_2_1 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  data_source <- c("教員資料表", "職員(工)資料表")
  
  flag_person_wide_flag62_2_1 <- expand.grid(organization_id = flag_person_wide_flag62_2_1$organization_id %>% as.character(), 
                                           source = data_source)
  flag_person_wide_flag62_2_1$flag62_2_1_r <-  ""
}

if('flag_person_wide_flag62_2_2' %in% ls()){ #如果flag_person_wide_flag62_2_2有建立成功
  print("flag_person_wide_flag62_2_2 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag62_2_2 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  data_source <- c("教員資料表", "職員(工)資料表")
  
  flag_person_wide_flag62_2_2 <- expand.grid(organization_id = flag_person_wide_flag62_2_2$organization_id %>% as.character(), 
                                             source = data_source)
  flag_person_wide_flag62_2_2$flag62_2_2_r <-  ""
}

if('flag_person_wide_flag62_2_3' %in% ls()){ #如果flag_person_wide_flag62_2_3有建立成功
  print("flag_person_wide_flag62_2_3 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag62_2_3 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  data_source <- c("教員資料表", "職員(工)資料表")
  
  flag_person_wide_flag62_2_3 <- expand.grid(organization_id = flag_person_wide_flag62_2_3$organization_id %>% as.character(), 
                                             source = data_source)
  flag_person_wide_flag62_2_3$flag62_2_3_r <-  ""
}

flag_person_wide_flag62 <- flag_person_wide_flag62_1 %>%
  full_join(flag_person_wide_flag62_2_1, by = c("organization_id", "source")) %>%
  full_join(flag_person_wide_flag62_2_2, by = c("organization_id", "source")) %>%
  full_join(flag_person_wide_flag62_2_3, by = c("organization_id", "source")) %>%
  select(c("organization_id", "source", "flag62_1_r", "flag62_2_1_r", "flag62_2_2_r", "flag62_2_3_r")) %>%
  mutate(flag62_r = paste(flag62_1_r, flag62_2_1_r, flag62_2_2_r, flag62_2_3_r, sep = "\n"))
flag_person_wide_flag62$flag62_r <- gsub("NA\n+", replacement="", flag_person_wide_flag62$flag62_r)
flag_person_wide_flag62$flag62_r <- gsub("\nNA+", replacement="", flag_person_wide_flag62$flag62_r)
flag_person_wide_flag62$flag62_r <- gsub("NA", replacement="", flag_person_wide_flag62$flag62_r)



#產生檢誤報告文字
flag62_temp <- flag_person_wide_flag62 %>%
  subset(flag62_r != "" & flag62_r != "\n") %>% 
  group_by(organization_id) %>%
  mutate(flag62_txt = paste(source, "之行政職資料不完整或不正確：", flag62_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag62_txt)) %>%
  distinct(organization_id, flag62_txt)

#根據organization_id，展開成寬資料(wide)
flag62 <- flag62_temp %>%
  dcast(organization_id ~ flag62_txt, value.var = "flag62_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag62)[2 : length(colnames(flag62))]
flag62$flag62 <- NA
for (i in temp){
  flag62$flag62 <- paste(flag62$flag62, flag62[[i]], sep = "； ")
}
flag62$flag62 <- gsub("NA； ", replacement="", flag62$flag62)
flag62$flag62 <- gsub("； NA", replacement="", flag62$flag62)

#產生檢誤報告文字
flag62 <- flag62 %>%
  subset(select = c(organization_id, flag62)) %>%
  distinct(organization_id, flag62) %>%
  mutate(flag62 = paste(flag62, "", sep = ""))
}else{
#偵測flag62是否存在。若不存在，則產生NA行
if('flag62' %in% ls()){
  print("flag62")
}else{
  flag62 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag62$flag62 <- ""
}
}
# flag64: 本校任職需扣除年資非0000者分布偏高。 -------------------------------------------------------------------
flag_person <- drev_person_1

flag_person$dese <- 0
flag_person$dese <- if_else(flag_person$desedym != "0000", 1, flag_person$dese)


flag_person$jj <- 1

flag_person_wide_flag64 <- aggregate(cbind(dese, jj) ~ organization_id, flag_person, sum)

flag_person_wide_flag64$flag_err <- 0
flag_person_wide_flag64$err_flag_txt <- if_else(flag_person_wide_flag64$dese / flag_person_wide_flag64$jj > 0.25, "扣除年資不為零的人數偏高，請再依欄位說明確認。", "")

if (dim(flag_person_wide_flag64 %>% subset(err_flag_txt != ""))[1] != 0){
#根據organization_id，展開成寬資料(wide)
flag64 <- flag_person_wide_flag64 %>%
  subset(err_flag_txt != "") %>%
  dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag64)[2 : length(colnames(flag64))]
flag64$flag64 <- NA
for (i in temp){
  flag64$flag64 <- paste(flag64$flag64, flag64[[i]], sep = "； ")
}
flag64$flag64 <- gsub("NA； ", replacement="", flag64$flag64)
flag64$flag64 <- gsub("； NA", replacement="", flag64$flag64)

#產生檢誤報告文字
flag64 <- flag64 %>%
  subset(select = c(organization_id, flag64)) %>%
  distinct(organization_id, flag64)
}else{
#偵測flag64是否存在。若不存在，則產生NA行
if('flag64' %in% ls()){
  print("flag64")
}else{
  flag64 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag64$flag64 <- ""
}
}
# flag80: 代理教師、兼任教師、鐘點教師、長期代課教師、約用教師、約聘僱教師的「本校到職日期」非屬本學期，請再確認。-------------------------------------------------------------------
flag_person <- drev_person_1

#代理教師、兼任教師、長期代課教師、鐘點教師、約聘僱教師、約用教師到職日過早

#兼任教師、長期代課教師、鐘點教師、約聘僱教師、約用教師到職日應為上一個學期開學日(每學期(年)需修改emp_year、emp_mon的時間)
flag_person$emp_year1 <- 111
flag_person$emp_mon1 <- 8

flag_person$arvy1 <- substr(flag_person$onbodat, 1, 3) %>% as.numeric()
flag_person$arvm1 <- substr(flag_person$onbodat, 4, 5) %>% as.numeric()

flag_person$err_emp1 <- if_else((flag_person$emptype %in% c("兼任", 
                                                            "長期代課", 
                                                            "鐘點教師", 
                                                            "約聘僱", 
                                                            "約用") 
                                  & flag_person$sertype == "教師") 
                                 & (flag_person$arvy1 * 12 + flag_person$arvm1) < (flag_person$emp_year1 * 12 + flag_person$emp_mon1), 1, 0)

#代理教師到職日應為上一個學期開學日-2年，依法規代理教師得續聘2次(每學期(年)需修改emp_year、emp_mon的時間)

#代理教師到職日應為上一個學期開學日-2年以上，聘任類別卻填"代理"，要請學校改為"代理(連)"
#若聘任類別直接填了"代理(連)"，視為學校已確認，不檢查
#仲賢：可能要改為上一個學期開學日-1年以上，因為法定可以連續聘任也算連續聘任
flag_person$emp_year2 <- flag_person$emp_year1 - 1
flag_person$emp_mon2 <- flag_person$emp_mon1

flag_person$arvy2 <- substr(flag_person$onbodat, 1, 3) %>% as.numeric()
flag_person$arvm2 <- substr(flag_person$onbodat, 4, 5) %>% as.numeric()

flag_person$err_emp2 <- if_else((flag_person$emptype == "代理" & flag_person$sertype == "教師") & (flag_person$arvy2 * 12 + flag_person$arvm2) < (flag_person$emp_year2 * 12 + flag_person$emp_mon2), 1, 0)

flag_person$emptypesertype <- paste(flag_person$emptype, flag_person$sertype, sep = "")
flag_person$emptypesertype <- if_else(flag_person$emptypesertype == "鐘點教師教師", "鐘點教師", flag_person$emptypesertype)

flag_person$err_flag <- if_else(flag_person$err_emp1 == 1 | flag_person$err_emp2 == 1, 1, 0)

#備註文字用
  #err_emp1: 兼任教師、長期代課教師、鐘點教師、約聘僱教師、約用教師到職日過早
  #err_emp2: 代理教師到職日過早
  #aggregate該校err_emp1及err_emp2 -> 該校err_emp出現在err_emp1 or err_emp2
flag_person_err_emp_detect <- aggregate(cbind(err_emp1, err_emp2) ~ organization_id, flag_person, sum) %>%
  rename(err_emp1_detect = err_emp1, err_emp2_detect = err_emp2)

flag_person <- flag_person %>%
  left_join(flag_person_err_emp_detect, by = "organization_id")

#加註
flag_person$name <- paste(flag_person$name, "（", flag_person$emptypesertype, " 到職日:", flag_person$onbodat, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id，展開成寬資料(wide)
flag_person_wide_flag80_1 <- tryCatch({
  flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, err_flag, err_emp1, err_emp2, err_emp1_detect, err_emp2_detect)) %>%
    subset(err_emp1 == 1) %>%
    dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt", fun.aggregate = first)
}, error = function(e) {
  NULL
})

if(!is.null(flag_person_wide_flag80_1)){
  #合併所有name
  temp <- colnames(flag_person_wide_flag80_1)[2 : length(colnames(flag_person_wide_flag80_1))]
  flag_person_wide_flag80_1$flag80_1_r <- NA
  for (i in temp){
    flag_person_wide_flag80_1$flag80_1_r <- paste(flag_person_wide_flag80_1$flag80_1_r, flag_person_wide_flag80_1[[i]], sep = " ")
  }
  flag_person_wide_flag80_1$flag80_1_r <- gsub("NA ", replacement="", flag_person_wide_flag80_1$flag80_1_r)
  flag_person_wide_flag80_1$flag80_1_r <- gsub(" NA", replacement="", flag_person_wide_flag80_1$flag80_1_r)
  flag_person_wide_flag80_1$flag80_1_r <- paste0(flag_person_wide_flag80_1$flag80_1_r, "\n（請依欄位說明，再協助確認是否為本次任職聘書/聘約之到職日期。）") #若#err_flag_1: 職稱或服務單位不合理，則加註
}else{
  print("flag_person_wide_flag80_1 not exists.")
  rm(flag_person_wide_flag80_1)
}

#根據organization_id，展開成寬資料(wide)
flag_person_wide_flag80_2 <- tryCatch({
  flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, err_flag, err_emp1, err_emp2, err_emp1_detect, err_emp2_detect)) %>%
    subset(err_emp2 == 1) %>%
    dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt")
}, error = function(e) {
  NULL
})

if(!is.null(flag_person_wide_flag80_2)){
  #合併所有name
  temp <- colnames(flag_person_wide_flag80_2)[2 : length(colnames(flag_person_wide_flag80_2))]
  flag_person_wide_flag80_2$flag80_2_r <- NA
  for (i in temp){
    flag_person_wide_flag80_2$flag80_2_r <- paste(flag_person_wide_flag80_2$flag80_2_r, flag_person_wide_flag80_2[[i]], sep = " ")
  }
  flag_person_wide_flag80_2$flag80_2_r <- gsub("NA ", replacement="", flag_person_wide_flag80_2$flag80_2_r)
  flag_person_wide_flag80_2$flag80_2_r <- gsub(" NA", replacement="", flag_person_wide_flag80_2$flag80_2_r)
  flag_person_wide_flag80_2$flag80_2_r <- paste0(flag_person_wide_flag80_2$flag80_2_r, "\n（請依欄位說明及簡報，再協助確認各學年(學期)聘任期間是否中斷超過一個月以上，若否，則認定為聘任未中斷（即『連續聘任』），該代理教師之「聘任類別」請填寫「代理(連)」。）") #若#err_flag_1: 職稱或服務單位不合理，則加註
}else{
  print("flag_person_wide_flag80_2 not exists.")
  rm(flag_person_wide_flag80_2)
}

if('flag_person_wide_flag80_1' %in% ls()){ #如果flag_person_wide_flag80_1有建立成功
  print("flag_person_wide_flag80_1 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag80_1 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  
  flag_person_wide_flag80_1$flag80_1_r <-  ""
}

if('flag_person_wide_flag80_2' %in% ls()){ #如果flag_person_wide_flag80_2有建立成功
  print("flag_person_wide_flag80_2 exists.")
}else{ #如果未建立成功，建立空白物件
  flag_person_wide_flag80_2 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  
  flag_person_wide_flag80_2$flag80_2_r <-  ""
}

flag_person_wide_flag80 <- flag_person_wide_flag80_1 %>%
  full_join(flag_person_wide_flag80_2, by = c("organization_id")) %>%
  select(c("organization_id", "flag80_1_r", "flag80_2_r")) %>%
  mutate(flag80_r = paste(flag80_1_r, flag80_2_r, sep = "\n"))
flag_person_wide_flag80$flag80_r <- gsub("NA\n+", replacement="", flag_person_wide_flag80$flag80_r)
flag_person_wide_flag80$flag80_r <- gsub("\nNA+", replacement="", flag_person_wide_flag80$flag80_r)


#產生檢誤報告文字
flag80 <- flag_person_wide_flag80 %>%
  subset(flag80_r != "") %>% 
  group_by(organization_id) %>%
  mutate(flag80 = paste("教員資料表需核對「本校到職日期」：",flag80_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag80)) %>%
  distinct(organization_id, flag80)
}else{
#偵測flag80是否存在。若不存在，則產生NA行
if('flag80' %in% ls()){
  print("flag80")
}else{
  flag80 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag80$flag80 <- ""
}
}
# flag82: 若請假類別填寫「留職停薪」，則留職停薪原因須填寫內容。 -------------------------------------------------------------------
flag_person <- drev_person_1

#抓出:請假類別填"留職停薪"，但留職停薪原因填N
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(grepl("留職停薪", flag_person$leave) & flag_person$levpay == "N", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("留職停薪", flag_person$leave) & flag_person$levpay == "Ｎ", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("留停", flag_person$leave) & flag_person$levpay == "N", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("留停", flag_person$leave) & flag_person$levpay == "Ｎ", 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（", "請假類別：", flag_person$leave, "；留職停薪原因：", flag_person$levpay, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag82 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag82)[3 : length(colnames(flag_person_wide_flag82))]
flag_person_wide_flag82$flag82_r <- NA
for (i in temp){
  flag_person_wide_flag82$flag82_r <- paste(flag_person_wide_flag82$flag82_r, flag_person_wide_flag82[[i]], sep = " ")
}
flag_person_wide_flag82$flag82_r <- gsub("NA ", replacement="", flag_person_wide_flag82$flag82_r)
flag_person_wide_flag82$flag82_r <- gsub(" NA", replacement="", flag_person_wide_flag82$flag82_r)

#產生檢誤報告文字
flag82_temp <- flag_person_wide_flag82 %>%
  group_by(organization_id) %>%
  mutate(flag82_txt = paste(source, "需修改請假類別、留職停薪原因：", flag82_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag82_txt)) %>%
  distinct(organization_id, flag82_txt)

#根據organization_id，展開成寬資料(wide)
flag82 <- flag82_temp %>%
  dcast(organization_id ~ flag82_txt, value.var = "flag82_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag82)[2 : length(colnames(flag82))]
flag82$flag82 <- NA
for (i in temp){
  flag82$flag82 <- paste(flag82$flag82, flag82[[i]], sep = "； ")
}
flag82$flag82 <- gsub("NA； ", replacement="", flag82$flag82)
flag82$flag82 <- gsub("； NA", replacement="", flag82$flag82)

#產生檢誤報告文字
flag82 <- flag82 %>%
  subset(select = c(organization_id, flag82)) %>%
  distinct(organization_id, flag82) %>%
  mutate(flag82 = paste(flag82, "", sep = ""))
}else{
#偵測flag82是否存在。若不存在，則產生NA行
if('flag82' %in% ls()){
  print("flag82")
}else{
  flag82 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag82$flag82 <- ""
}
}
# flag89: 專任教師、代理教師原則須具大專以上學歷，請再確認實際情況及所填資料。 -------------------------------------------------------------------
flag_person <- drev_person_1

#專任、代理教師最高學歷是否為大專以上不應為N
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$degree == "N" 
                                & flag_person$emptype %in% c("專任", "代理", "代理(連)") 
                                & flag_person$sertype == "教師", 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag89 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag89)[3 : length(colnames(flag_person_wide_flag89))]
flag_person_wide_flag89$flag89_r <- NA
for (i in temp){
  flag_person_wide_flag89$flag89_r <- paste(flag_person_wide_flag89$flag89_r, flag_person_wide_flag89[[i]], sep = " ")
}
flag_person_wide_flag89$flag89_r <- gsub("NA ", replacement="", flag_person_wide_flag89$flag89_r)
flag_person_wide_flag89$flag89_r <- gsub(" NA", replacement="", flag_person_wide_flag89$flag89_r)

#產生檢誤報告文字
flag89_temp <- flag_person_wide_flag89 %>%
  group_by(organization_id) %>%
  mutate(flag89_txt = paste(source, "：", flag89_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag89_txt)) %>%
  distinct(organization_id, flag89_txt)

#根據organization_id，展開成寬資料(wide)
flag89 <- flag89_temp %>%
  dcast(organization_id ~ flag89_txt, value.var = "flag89_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag89)[2 : length(colnames(flag89))]
flag89$flag89 <- NA
for (i in temp){
  flag89$flag89 <- paste(flag89$flag89, flag89[[i]], sep = "； ")
}
flag89$flag89 <- gsub("NA； ", replacement="", flag89$flag89)
flag89$flag89 <- gsub("； NA", replacement="", flag89$flag89)

#產生檢誤報告文字
flag89 <- flag89 %>%
  subset(select = c(organization_id, flag89)) %>%
  distinct(organization_id, flag89) %>%
  mutate(flag89 = paste(flag89, "（請再協助確認渠等人員畢業學歷）", sep = ""))
}else{
#偵測flag89是否存在。若不存在，則產生NA行
if('flag89' %in% ls()){
  print("flag89")
}else{
  flag89 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag89$flag89 <- ""
}
}
# flag90: 校內行政職務，原則由專任或代理教師兼任，請再確認實際情況及所填資料。 -------------------------------------------------------------------
flag_person <- drev_person_1

#兼任、長期代課、專職族語老師、鐘點教師、約聘僱、約用教師，不應有兼任行政職務，也不可擔任導師
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$emptype %in% c("兼任", 
                                                           "長期代課", 
                                                           "專職族語老師", 
                                                           "鐘點教師", 
                                                           "約聘僱", 
                                                           "約用")
                                & flag_person$sertype == "教師" 
                                & flag_person$admintitle1 != "N" , 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（", flag_person$emptype, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag90 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag90)[3 : length(colnames(flag_person_wide_flag90))]
flag_person_wide_flag90$flag90_r <- NA
for (i in temp){
  flag_person_wide_flag90$flag90_r <- paste(flag_person_wide_flag90$flag90_r, flag_person_wide_flag90[[i]], sep = " ")
}
flag_person_wide_flag90$flag90_r <- gsub("NA ", replacement="", flag_person_wide_flag90$flag90_r)
flag_person_wide_flag90$flag90_r <- gsub(" NA", replacement="", flag_person_wide_flag90$flag90_r)

#產生檢誤報告文字
flag90_temp <- flag_person_wide_flag90 %>%
  group_by(organization_id) %>%
  mutate(flag90_txt = paste("姓名：", flag90_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag90_txt)) %>%
  distinct(organization_id, flag90_txt)

#根據organization_id，展開成寬資料(wide)
flag90 <- flag90_temp %>%
  dcast(organization_id ~ flag90_txt, value.var = "flag90_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag90)[2 : length(colnames(flag90))]
flag90$flag90 <- NA
for (i in temp){
  flag90$flag90 <- paste(flag90$flag90, flag90[[i]], sep = "； ")
}
flag90$flag90 <- gsub("NA； ", replacement="", flag90$flag90)
flag90$flag90 <- gsub("； NA", replacement="", flag90$flag90)

#產生檢誤報告文字
flag90 <- flag90 %>%
  subset(select = c(organization_id, flag90)) %>%
  distinct(organization_id, flag90) %>%
  mutate(flag90 = paste(flag90, "（人事資料顯示該教師兼任行政職務）\n", "（校內行政職務原則由專任教師兼任，請協助再確認上述教師是否兼任行政職，或協助再確認上述教師之聘任類別）", sep = ""))
}else{
#偵測flag90是否存在。若不存在，則產生NA行
if('flag90' %in% ls()){
  print("flag90")
}else{
  flag90 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag90$flag90 <- ""
}
}
# flag94: 職員（工）的「職務名稱」與「聘任類別」不相符應。 -------------------------------------------------------------------
flag_person <- drev_person_1

#職員工若為專任，職務名稱不可出現"約僱"、"約聘雇"、"約雇"、"約聘雇"、"約聘"之關鍵字
#私立學校flag94還是檢查，但屬於確認項目
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(grepl("約僱", flag_person$admintitle0) & flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("約聘僱", flag_person$admintitle0) & flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("約雇", flag_person$admintitle0) & flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("約聘雇", flag_person$admintitle0) & flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, flag_person$err_flag)
flag_person$err_flag <- if_else(grepl("約聘", flag_person$admintitle0) & flag_person$emptype == "專任" & flag_person$source == "職員(工)資料表", 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（職務名稱：", flag_person$admintitle0, "；）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag94 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag94)[3 : length(colnames(flag_person_wide_flag94))]
flag_person_wide_flag94$flag94_r <- NA
for (i in temp){
  flag_person_wide_flag94$flag94_r <- paste(flag_person_wide_flag94$flag94_r, flag_person_wide_flag94[[i]], sep = " ")
}
flag_person_wide_flag94$flag94_r <- gsub("NA ", replacement="", flag_person_wide_flag94$flag94_r)
flag_person_wide_flag94$flag94_r <- gsub(" NA", replacement="", flag_person_wide_flag94$flag94_r)

#產生檢誤報告文字
flag94_temp <- flag_person_wide_flag94 %>%
  group_by(organization_id) %>%
  mutate(flag94_txt = paste(source, "姓名：", flag94_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag94_txt)) %>%
  distinct(organization_id, flag94_txt)

#根據organization_id，展開成寬資料(wide)
flag94 <- flag94_temp %>%
  dcast(organization_id ~ flag94_txt, value.var = "flag94_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag94)[2 : length(colnames(flag94))]
flag94$flag94 <- NA
for (i in temp){
  flag94$flag94 <- paste(flag94$flag94, flag94[[i]], sep = "； ")
}
flag94$flag94 <- gsub("NA； ", replacement="", flag94$flag94)
flag94$flag94 <- gsub("； NA", replacement="", flag94$flag94)

#產生檢誤報告文字
flag94 <- flag94 %>%
  subset(select = c(organization_id, flag94)) %>%
  distinct(organization_id, flag94) %>%
  mutate(flag94 = paste(flag94, "（請確認上開職員(工)之『聘任類別』及『職務名稱』。凡以簽訂契約方式任用之人員，無論是否為編制內員額，其『聘任類別』皆請修正為『約聘僱』。並請再協助確認上開職員(工)『職務名稱』是否正確。惟貴校職員(工)如具正式公務人員身分者，則其『聘任類別』原則應是『專任』。）（貴校如僅有本項檢查須再確認修正資料，則不列入國教署催辦範圍，惟請儘速確認修正送出資料。）", sep = ""))
}else{
#偵測flag94是否存在。若不存在，則產生NA行
if('flag94' %in% ls()){
  print("flag94")
}else{
  flag94 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag94$flag94 <- ""
}
}
# spe3: 本校到職日期晚於填報基準日。 -------------------------------------------------------------------
flag_person <- drev_person_1

#本校到職日期晚於填報基準日。
flag_person$survey_year <- 112
flag_person$survey_mon <- 9

flag_person$arvy <- substr(flag_person$onbodat, 1, 3) %>% as.numeric()
flag_person$arvm <- substr(flag_person$onbodat, 4, 5) %>% as.numeric()

flag_person$err_spe <- if_else((flag_person$arvy * 12 + flag_person$arvm) > (flag_person$survey_year * 12 + flag_person$survey_mon), 1, 0)

#加註
flag_person$name <- paste(flag_person$name, "（", flag_person$onbodat, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_spe == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_spe == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_spe3 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_spe)) %>%
  subset(err_spe == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_spe3)[3 : length(colnames(flag_person_wide_spe3))]
flag_person_wide_spe3$spe3_r <- NA
for (i in temp){
  flag_person_wide_spe3$spe3_r <- paste(flag_person_wide_spe3$spe3_r, flag_person_wide_spe3[[i]], sep = " ")
}
flag_person_wide_spe3$spe3_r <- gsub("NA ", replacement="", flag_person_wide_spe3$spe3_r)
flag_person_wide_spe3$spe3_r <- gsub(" NA", replacement="", flag_person_wide_spe3$spe3_r)

#產生檢誤報告文字
spe3_temp <- flag_person_wide_spe3 %>%
  group_by(organization_id) %>%
  mutate(spe3_txt = paste(source, "：", spe3_r, sep = ""), "") %>%
  subset(select = c(organization_id, spe3_txt)) %>%
  distinct(organization_id, spe3_txt)

#根據organization_id，展開成寬資料(wide)
spe3 <- spe3_temp %>%
  dcast(organization_id ~ spe3_txt, value.var = "spe3_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(spe3)[2 : length(colnames(spe3))]
spe3$spe3 <- NA
for (i in temp){
  spe3$spe3 <- paste(spe3$spe3, spe3[[i]], sep = "； ")
}
spe3$spe3 <- gsub("NA； ", replacement="", spe3$spe3)
spe3$spe3 <- gsub("； NA", replacement="", spe3$spe3)

#產生檢誤報告文字
spe3 <- spe3 %>%
  subset(select = c(organization_id, spe3)) %>%
  distinct(organization_id, spe3) %>%
  mutate(spe3 = paste(spe3, "（請確認修正到職日期，並請以資料基準日112年9月30日當時情況為準）", sep = ""))
}else{
#偵測spe3是否存在。若不存在，則產生NA行
if('spe3' %in% ls()){
  print("spe3")
}else{
  spe3 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  spe3$spe3 <- ""
}
}
# spe5: 教職員工畢業學校若為(科技)大學或(技術)學院，學歷資訊原則於「學士」、「碩士」或「博士」學歷欄位填列，而非「副學士」。 -------------------------------------------------------------------
flag_person <- drev_person_1

#副學士學位畢業學校名稱不可出現"大學"及"學院"，可出現"專科學校"
flag_person$err_flag_adegreeu1 <- 0
flag_person$err_flag_adegreeu2 <- 0
flag_person$err_flag_adegreeu1 <- if_else(grepl("大學", flag_person$adegreeu1), 1, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("學院", flag_person$adegreeu1), 1, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("科大", flag_person$adegreeu1), 1, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu2 <- if_else(grepl("大學", flag_person$adegreeu2), 1, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("學院", flag_person$adegreeu2), 1, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("科大", flag_person$adegreeu2), 1, flag_person$err_flag_adegreeu2)
#達姆施塔特工業大學（德語：Technische Universitat Darmstadt），是德國歷史悠久的理工大學
flag_person$err_flag_adegreeu2 <- if_else(grepl("Darmstadt$", flag_person$adegreeu2), 1, flag_person$err_flag_adegreeu2)
#副學士的情況
flag_person$err_flag_adegreeu1 <- if_else(grepl("專科", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("二專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("二年制", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("五專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("五年制", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("商專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("農專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("空專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("三專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu1 <- if_else(grepl("護專", flag_person$adegreeu1), 0, flag_person$err_flag_adegreeu1)
flag_person$err_flag_adegreeu2 <- if_else(grepl("專科", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("二專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("二年制", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("五專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("五年制", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("商專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("農專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("空專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("三專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)
flag_person$err_flag_adegreeu2 <- if_else(grepl("護專", flag_person$adegreeu2), 0, flag_person$err_flag_adegreeu2)

flag_person$err_flag <- flag_person$err_flag_adegreeu1 + flag_person$err_flag_adegreeu2

#加註學士學位畢業學校名稱
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag_adegreeu1 == 1 ~ paste(flag_person$name, "（副學士學位畢業學校（一）：", flag_person$adegreeu1, "）", sep = ""),
  flag_person$err_flag_adegreeu2 == 1 ~ paste(flag_person$name, "（副學士學位畢業學校（二）：", flag_person$adegreeu2, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_spe5 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_spe5)[3 : length(colnames(flag_person_wide_spe5))]
flag_person_wide_spe5$spe5_r <- NA
for (i in temp){
  flag_person_wide_spe5$spe5_r <- paste(flag_person_wide_spe5$spe5_r, flag_person_wide_spe5[[i]], sep = " ")
}
flag_person_wide_spe5$spe5_r <- gsub("NA ", replacement="", flag_person_wide_spe5$spe5_r)
flag_person_wide_spe5$spe5_r <- gsub(" NA", replacement="", flag_person_wide_spe5$spe5_r)

#產生檢誤報告文字
spe5_temp <- flag_person_wide_spe5 %>%
  group_by(organization_id) %>%
  mutate(spe5_txt = paste(source, "：", spe5_r, sep = ""), "") %>%
  subset(select = c(organization_id, spe5_txt)) %>%
  distinct(organization_id, spe5_txt)

#根據organization_id，展開成寬資料(wide)
spe5 <- spe5_temp %>%
  dcast(organization_id ~ spe5_txt, value.var = "spe5_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(spe5)[2 : length(colnames(spe5))]
spe5$spe5 <- NA
for (i in temp){
  spe5$spe5 <- paste(spe5$spe5, spe5[[i]], sep = "； ")
}
spe5$spe5 <- gsub("NA； ", replacement="", spe5$spe5)
spe5$spe5 <- gsub("； NA", replacement="", spe5$spe5)

#產生檢誤報告文字
spe5 <- spe5 %>%
  subset(select = c(organization_id, spe5)) %>%
  distinct(organization_id, spe5) %>%
  mutate(spe5 = paste(spe5, "（請確認以上人員畢業證書所載學位別。若最高學歷畢業學校為(科技/空中)大學、(技術)學院或其他技職校院，且為專科學制，請於「副學士或專科畢業學校」欄位中在校名後註記專科學制或專科部）", sep = ""))
}else{
#偵測spe5是否存在。若不存在，則產生NA行
if('spe5' %in% ls()){
  print("spe5")
}else{
  spe5 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  spe5$spe5 <- ""
}
}
# spe6: 各教育階段學歷資料內容是否完整正確。-------------------------------------------------------------------
# 例如：
# 1.	各學歷階段「國別」非填入「本國」或者外交部網站之世界各國名稱一覽表的國家名稱（或者至少須足以辨識國家）。
# 2.	各學歷階段「學校」填入非學校名稱。
# 3.	各學歷階段「系所」填入非系所名稱。
# 4.	需有專科學歷，才能報考碩士研究所（若為逕讀碩士，副學士不得為N）。
# 5.	需有學士學歷，才能報考博士研究所（若為逕讀博士，學士不得為N或填逕讀博士）。
# 6.	學士學位欄位若填列「逕讀碩士」，應填列碩士學位（不應為N）。
# 7.	碩士學位欄位若填列「逕讀博士」，應填列博士學位（不應為N）。

flag_person <- drev_person_1

#博士學位畢業學校國別（一）
flag_person$err_ddegreen1 <- 0
flag_person$err_ddegreen1 <- if_else(grepl("博士", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("碩士", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("學士", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("副學士", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("大學", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("分校", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("學院", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("科大", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("學校", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("官校", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("預校", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("書院", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("專科", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("藝專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("海專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("工專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("護專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("家專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("商專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("行專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("農專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("體專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("藥專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("師專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("醫專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("語專", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("university", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("University", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("UNIVERSITY", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("college", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("College", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("COLLEGE", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("系", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("所", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("班$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("不分科系", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("不分系", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("department", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("Department", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("DEPARTMENT", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("兼課", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("最高學歷", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^Y$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^待查詢$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^無$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^外國$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^國立$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^歐洲$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^美洲$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^亞洲$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^非洲$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("^大洋洲$", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("肄業", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("學分班", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)
flag_person$err_ddegreen1 <- if_else(grepl("結業", flag_person$ddegreen1), 1, flag_person$err_ddegreen1)

#博士學位畢業學校（一）
flag_person$err_ddegreeu1 <- 1
flag_person$err_ddegreeu1 <- if_else(grepl("大學", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("分校", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("學院", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("師大", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("科大", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("學校", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("官校", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("預校", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("書院", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("體院", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("專科", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("藝專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("海專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("工專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("護專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("家專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("商專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("行專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("農專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("體專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("師專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("藥專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("醫專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("語專", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("士校", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("專校$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("university", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("University", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("UNIVERSITY", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Uni$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("college", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("College", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("COLLEGE", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Universidad", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("UNIVERSIDAD", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Conservatory", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("CRD", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("ENM", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("CRC", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("EMMA", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("CRR", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("CNR", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("TheNewSchool", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Hochschule", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Universitat", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Institute$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("StellenboschUni$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^TUDarmstadt$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^N$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^莫斯科柴可夫斯基$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("音樂院$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("音樂研究所$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("大?$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("研究所博士班$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^中興法商$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^待查詢$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("本國", flag_person$ddegreeu1), 1, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("^日本國立岡山大學$", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("肄業", flag_person$ddegreeu1), 1, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("學分班", flag_person$ddegreeu1), 1, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("結業", flag_person$ddegreeu1), 1, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("籌備處$", flag_person$ddegreeu1), 1, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("Academy", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("academy", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)
flag_person$err_ddegreeu1 <- if_else(grepl("ACADEMY", flag_person$ddegreeu1), 0, flag_person$err_ddegreeu1)

#博士學位畢業系所（一）
flag_person$err_ddegreeg1 <- 0
flag_person$err_ddegreeg1 <- if_else(grepl("^博士$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("碩士", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("學士", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("副學士", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("大學", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("分校", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("^學院$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("科大", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("學校", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("官校", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("預校", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("書院", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("專科", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("藝專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("海專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("工專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("護專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("家專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("商專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("行專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("農專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("體專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("藥專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("師專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("醫專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("語專", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("university", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("University", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("UNIVERSITY", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("college", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("College", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("COLLEGE", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("兼課", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("最高學歷", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("^Y$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("^待查詢$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("^無$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("肄業", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("學分班", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("結業", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(grepl("行政$", flag_person$ddegreeg1), 1, flag_person$err_ddegreeg1)

#博士學位畢業學校國別（二）
flag_person$err_ddegreen2 <- 0
flag_person$err_ddegreen2 <- if_else(grepl("博士", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("碩士", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("學士", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("副學士", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("大學", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("分校", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("學院", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("科大", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("學校", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("官校", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("預校", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("書院", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("專科", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("藝專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("海專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("工專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("護專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("家專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("商專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("行專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("農專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("體專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("藥專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("師專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("醫專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("語專", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("university", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("University", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("UNIVERSITY", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("college", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("College", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("COLLEGE", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("系", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("所", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("班$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("不分科系", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("不分系", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("department", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("Department", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("DEPARTMENT", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("兼課", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("最高學歷", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^Y$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^待查詢$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^無$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^外國$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^國立$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^歐洲$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^美洲$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^亞洲$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^非洲$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("^大洋洲$", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("肄業", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("學分班", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)
flag_person$err_ddegreen2 <- if_else(grepl("結業", flag_person$ddegreen2), 1, flag_person$err_ddegreen2)

#博士學位畢業學校（二）
flag_person$err_ddegreeu2 <- 1
flag_person$err_ddegreeu2 <- if_else(grepl("大學", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("分校", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("學院", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("師大", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("科大", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("學校", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("官校", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("預校", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("書院", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("體院", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("專科", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("藝專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("海專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("工專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("護專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("家專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("商專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("行專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("農專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("體專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("師專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("藥專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("醫專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("語專", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("士校", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("專校$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("university", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("University", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("UNIVERSITY", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Uni$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("college", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("College", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("COLLEGE", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Universidad", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("UNIVERSIDAD", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Conservatory", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("CRD", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("ENM", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("CRC", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("EMMA", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("CRR", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("CNR", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("TheNewSchool", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Hochschule", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Universitat", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Institute$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("StellenboschUni$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^TUDarmstadt$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^N$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^莫斯科柴可夫斯基$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("音樂院$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("音樂研究所$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("大?$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("研究所博士班$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^中興法商$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^待查詢$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("本國", flag_person$ddegreeu2), 1, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("^日本國立岡山大學$", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("肄業", flag_person$ddegreeu2), 1, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("學分班", flag_person$ddegreeu2), 1, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("結業", flag_person$ddegreeu2), 1, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("籌備處$", flag_person$ddegreeu2), 1, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("Academy", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("academy", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)
flag_person$err_ddegreeu2 <- if_else(grepl("ACADEMY", flag_person$ddegreeu2), 0, flag_person$err_ddegreeu2)

#博士學位畢業系所（二）
flag_person$err_ddegreeg2 <- 0
flag_person$err_ddegreeg2 <- if_else(grepl("^博士$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("碩士", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("學士", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("副學士", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("大學", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("分校", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("^學院$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("科大", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("學校", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("官校", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("預校", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("書院", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("專科", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("藝專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("海專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("工專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("護專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("家專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("商專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("行專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("農專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("體專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("藥專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("師專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("醫專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("語專", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("university", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("University", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("UNIVERSITY", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("college", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("College", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("COLLEGE", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("兼課", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("最高學歷", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("^Y$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("^待查詢$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("^無$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("肄業", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("學分班", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("結業", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(grepl("行政$", flag_person$ddegreeg2), 1, flag_person$err_ddegreeg2)

#碩士學位畢業學校國別（一）
flag_person$err_mdegreen1 <- 0
flag_person$err_mdegreen1 <- if_else(grepl("博士", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("碩士", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("學士", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("副學士", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("大學", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("分校", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("學院", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("科大", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("學校", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("官校", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("預校", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("書院", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("專科", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("藝專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("海專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("工專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("護專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("家專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("商專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("行專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("農專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("體專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("藥專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("師專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("醫專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("語專", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("university", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("University", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("UNIVERSITY", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("college", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("College", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("COLLEGE", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("系", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("所", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("班$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("不分科系", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("不分系", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("department", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("Department", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("DEPARTMENT", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^逕讀", flag_person$mdegreen1), 0, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^逕讀碩士$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^兼課", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^最高學歷", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^Y$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^待查詢$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^無$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^外國$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^國立$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^歐洲$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^亞洲$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^美洲$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^非洲$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("^大洋洲$", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("肄業", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("學分班", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)
flag_person$err_mdegreen1 <- if_else(grepl("結業", flag_person$mdegreen1), 1, flag_person$err_mdegreen1)

#碩士學位畢業學校學校（一）
flag_person$err_mdegreeu1 <- 1
flag_person$err_mdegreeu1 <- if_else(grepl("大學", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("分校", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("學院", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("師院", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("師大", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("科大", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("學校", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("官校", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("預校", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("書院", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("體院", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("專科", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("藝專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("海專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("工專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("護專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("家專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("商專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("行專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("農專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("體專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("師專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("藥專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("醫專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("語專", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("士校", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("專校$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("逕讀", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("音樂院$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("音樂研究所$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("university", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("University", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("UNIVERSITY", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Uni$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("UNIVERSIT", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("college", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("College", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("COLLEGE", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Universidad$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("UNIVERSIDAD$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Conservatory$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("CRD$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("ENM$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("CRC$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("EMMA$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("CRR$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("CNR$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("TheNewSchool$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Hochschule$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("BergenSchoolofArchitecture$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Universitat$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("Institute$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("StellenboschUni$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^TUDarmstadt$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^大?$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^研究所博士班$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^中興法商$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^N$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^待查詢$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^無$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^離職$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^因故$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^NavalPostgraduateSchool$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^BiblicalInterpretationLondonSchoolofTheology$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^DallasBaptistUniv$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^NewYorkFilmAcademy$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^ConservatorioStatalediMilano“GiuseppeVerdi”Italia$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^衛理神學研究院$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^KnowledgeSystemInstitute$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^ColumbiaBiblicalSeminaryandSchoolofMissions$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^UnitecInstituteofTechnology$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^巴拉圭高等戰略研究院$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^本國$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^肄業$", flag_person$mdegreeu1), 1, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^學分班$", flag_person$mdegreeu1), 1, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^籌備處$", flag_person$mdegreeu1), 1, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^高雄餐旅$", flag_person$mdegreeu1), 1, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^universiteJeanMoulinLyon3$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^UniversityCollegeLondon$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^BirminghamUiversity$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^ColumbiaUniversity哥倫比亞大學MathematicsEducation$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^StevensInstituteofTechnology，NJ，USA$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^UNITEDSTATESSPORTSACADEMY$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^KnowledgeSystemsInstitute$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("DomusAcademy", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("DOMUSACADEMY", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)
flag_person$err_mdegreeu1 <- if_else(grepl("^UniversiteStendhalGrenobleIII$", flag_person$mdegreeu1), 0, flag_person$err_mdegreeu1)

#碩士學位畢業系所（一）
flag_person$err_mdegreeg1 <- 0
flag_person$err_mdegreeg1 <- if_else(grepl("博士", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^逕讀博士$", flag_person$mdegreeg1), 0, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^碩士$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("學士", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("副學士", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("大學", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("分校", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^學院$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("科大", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("學校", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("官校", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("預校", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("書院", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("專科", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("藝專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("海專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("工專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("護專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("家專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("商專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("行專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("農專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("體專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("藥專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("師專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("醫專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("語專", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("university", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("University", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("UNIVERSITY", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("college", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("College", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("COLLEGE", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("兼課", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("最高學歷", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^Y$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^待查詢$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^無$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("肄業", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("學分班", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("行政$", flag_person$mdegreeg1), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^教育政策與行政$", flag_person$mdegreeg1) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^社會教育學系學校圖書行政$", flag_person$mdegreeg1) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(grepl("^工業教育學系技職教育行政$", flag_person$mdegreeg1) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg1)

#碩士學位畢業學校國別（二）
flag_person$err_mdegreen2 <- 0
flag_person$err_mdegreen2 <- if_else(grepl("博士", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("碩士", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("學士", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("副學士", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("大學", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("分校", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("學院", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("科大", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("學校", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("官校", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("預校", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("書院", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("專科", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("藝專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("海專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("工專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("護專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("家專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("商專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("行專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("農專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("體專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("藥專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("師專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("醫專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("語專", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("university", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("University", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("UNIVERSITY", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("college", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("College", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("COLLEGE", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("系", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("所", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("班$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("不分科系", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("不分系", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("department", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("Department", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("DEPARTMENT", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^逕讀", flag_person$mdegreen2), 0, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^逕讀碩士$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^兼課", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^最高學歷", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^Y$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^待查詢$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^無$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^外國$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^國立$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^歐洲$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^亞洲$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^美洲$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^非洲$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("^大洋洲$", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("肄業", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)
flag_person$err_mdegreen2 <- if_else(grepl("學分班", flag_person$mdegreen2), 1, flag_person$err_mdegreen2)

#碩士學位畢業學校學校（二）
flag_person$err_mdegreeu2 <- 1
flag_person$err_mdegreeu2 <- if_else(grepl("大學", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("分校", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("學院", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("師院", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("師大", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("科大", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("學校", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("官校", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("預校", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("書院", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("體院", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("專科", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("藝專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("海專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("工專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("護專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("家專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("商專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("行專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("農專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("體專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("師專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("藥專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("醫專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("語專", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("士校", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("專校$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("逕讀$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("音樂院$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("音樂研究所$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("university$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("University$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("UNIVERSITY$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Uni$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("college", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("College", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("COLLEGE", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Universidad$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("UNIVERSIDAD$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Conservatory$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("CRD$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("ENM$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("CRC$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("EMMA$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("CRR$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("CNR$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("TheNewSchool$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Hochschule$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("BergenSchoolofArchitecture$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Universitat$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("Institute$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("StellenboschUni$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^TUDarmstadt$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^大?$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^研究所博士班$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^中興法商$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^N$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^待查詢$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^無$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^離職$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^因故$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^NavalPostgraduateSchool$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^BiblicalInterpretationLondonSchoolofTheology$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^DallasBaptistUniv$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^NewYorkFilmAcademy$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^ConservatorioStatalediMilano“GiuseppeVerdi”Italia$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^衛理神學研究院$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^KnowledgeSystemInstitute$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^ColumbiaBiblicalSeminaryandSchoolofMissions$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^UnitecInstituteofTechnology$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^巴拉圭高等戰略研究院$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^本國$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^肄業$", flag_person$mdegreeu2), 1, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^學分班$", flag_person$mdegreeu2), 1, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^籌備處$", flag_person$mdegreeu2), 1, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^高雄餐旅$", flag_person$mdegreeu2), 1, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^universiteJeanMoulinLyon3$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^UniversityCollegeLondon$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^BirminghamUiversity$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^ColumbiaUniversity哥倫比亞大學MathematicsEducation$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^StevensInstituteofTechnology，NJ，USA$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^UNITEDSTATESSPORTSACADEMY$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^KnowledgeSystemsInstitute$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("DomusAcademy", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("DOMUSACADEMY", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)
flag_person$err_mdegreeu2 <- if_else(grepl("^UniversiteStendhalGrenobleIII$", flag_person$mdegreeu2), 0, flag_person$err_mdegreeu2)

#碩士學位畢業系所（二）
flag_person$err_mdegreeg2 <- 0
flag_person$err_mdegreeg2 <- if_else(grepl("博士", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^逕讀博士$", flag_person$mdegreeg2), 0, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^碩士$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("學士", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("副學士", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("大學", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("分校", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^學院$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("科大", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("學校", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("官校", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("預校", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("書院", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("專科", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("藝專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("海專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("工專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("護專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("家專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("商專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("行專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("農專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("體專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("藥專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("師專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("醫專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("語專", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("university", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("University", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("UNIVERSITY", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("college", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("College", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("COLLEGE", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("兼課", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("最高學歷", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^Y$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^待查詢$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^無$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("肄業", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("學分班", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("行政$", flag_person$mdegreeg2), 1, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^教育政策與行政$", flag_person$mdegreeg2) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^社會教育學系學校圖書行政$", flag_person$mdegreeg2) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(grepl("^工業教育學系技職教育行政$", flag_person$mdegreeg2) & (grepl("國立臺灣師範大學", flag_person$mdegreeu1) | grepl("國立台灣師範大學", flag_person$mdegreeu1)), 0, flag_person$err_mdegreeg2)

#學士學位畢業學校國別（一）
flag_person$err_bdegreen1 <- 0
flag_person$err_bdegreen1 <- if_else(grepl("博士", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("碩士", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("學士", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("副學士", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("大學", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("分校", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("學院", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("科大", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("學校", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("官校", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("預校", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("書院", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("專科", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("藝專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("海專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("工專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("護專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("家專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("商專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("行專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("農專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("體專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("藥專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("師專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("醫專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("語專", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("university", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("University", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("UNIVERSITY", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("college", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("College", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("COLLEGE", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("系", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("所", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("班$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("不分科系", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("不分系", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("department", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("Department", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("DEPARTMENT", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^逕讀博士$", flag_person$bdegreen1), 0, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreen1), 0, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^逕行修讀碩士$", flag_person$bdegreen1), 0, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("兼課", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("最高學歷", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^Y$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^待查詢$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^無$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^外國$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^國立$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^歐洲$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^亞洲$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^美洲$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^非洲$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("^大洋洲$", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("肄業", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("學分班", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)
flag_person$err_bdegreen1 <- if_else(grepl("結業", flag_person$bdegreen1), 1, flag_person$err_bdegreen1)

#學士學位畢業學校（一）
flag_person$err_bdegreeu1 <- 1
flag_person$err_bdegreeu1 <- if_else(grepl("大學", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("分校", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("學院", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("師大", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("科大", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("教大", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("學校", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("官校", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("預校", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("書院", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("體院", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("師院", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("專科", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("藝專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("海專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("工專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("護專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("家專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("商專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("行專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("農專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("體專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("師專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("藥專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("醫專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("語專", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("士校", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("專校$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("逕讀", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("音樂院$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
#flag_person$err_bdegreeu1 <- if_else(grepl("音樂研究所$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("university", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("University", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("UNIVERSITY", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Uni$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("college", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("College", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("COLLEGE", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Universidad", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("UNIVERSIDAD", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Conservatory", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("CRD", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("ENM", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("CRC", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("EMMA", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("CRR", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("CNR", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("TheNewSchool", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Hochschule", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Universitat", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("StellenboschUni$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^TUDarmstadt$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("大?$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^中興法商$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^N$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^待查詢$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^無$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("離職", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("因故", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("VirginiaMilitaryInstitute", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^LISAA$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^IstitutoSecoli$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^輔大$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^UnivstersityOFDelaware$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^UinvofCentralOklahoma$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^赫拉德茨克拉洛韋$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^ConservatorioStatalediMilano“GiuseppeVerdi”Italia$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^陸軍官校專科班$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("中興法商", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("國立體院", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("逕獨碩士", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("UNISA", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("Univerity", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("山口?立大?", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("ColumbiaBiblicalSeminaryandSchoolofMissions", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("本國", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("肄業", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("學分班", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("結業", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("籌備處$", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^教育學院$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^高雄餐旅$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^台灣體大$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^國立空大$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^台灣體院$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^CityandGuildsofLondonArtSchool$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^BirminghamUiversity$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^NewJerseyInstituteofTechnology$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^CollegeofEducationPotchefstroomSA$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^?校法人????園?????????????西$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^同等學力$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^政戰正規班$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^日本國立埼玉大學$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^日本國立埼玉大學教養學部$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^日本國立奈良教育大學（學院）$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^日本國立熊本大學$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("^ConservatoriostatalediMilano“GiuseppeVerdi”Italia$", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("所", flag_person$bdegreeu1), 1, flag_person$err_bdegreeu1)
flag_person$err_bdegreeu1 <- if_else(grepl("逕行修讀", flag_person$bdegreeu1), 0, flag_person$err_bdegreeu1)

#學士學位畢業系所（一）
flag_person$err_bdegreeg1 <- 0
flag_person$err_bdegreeg1 <- if_else(grepl("博士", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("碩士", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreeg1), 0, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^學士$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("副學士", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("大學", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("分校", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^學院$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("科大", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("學校", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("官校", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("預校", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("書院", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("專科", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("藝專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("海專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("工專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("護專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("家專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("商專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("行專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("農專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("體專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("藥專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("師專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("醫專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("語專", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("university", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("University", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("UNIVERSITY", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("college", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("College", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("COLLEGE", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("兼課", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("最高學歷", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^Y$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^待查詢$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^無$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^逕獨碩士$", flag_person$bdegreeg1), 0, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^逕行修讀碩士$", flag_person$bdegreeg1), 0, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("肄業", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("學分班", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("結業", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("行政$", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("所", flag_person$bdegreeg1), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreeg1), 0, flag_person$err_bdegreeg1)

#學士學位畢業學校國別（二）
flag_person$err_bdegreen2 <- 0
flag_person$err_bdegreen2 <- if_else(grepl("博士", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("碩士", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("學士", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("副學士", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("大學", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("分校", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("學院", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("科大", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("學校", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("官校", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("預校", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("書院", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("專科", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("藝專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("海專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("工專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("護專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("家專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("商專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("行專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("農專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("體專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("藥專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("師專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("醫專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("語專", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("university", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("University", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("UNIVERSITY", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("college", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("College", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("COLLEGE", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("系", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("所", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("班$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("不分科系", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("不分系", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("department", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("Department", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("DEPARTMENT", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^逕讀博士$", flag_person$bdegreen2), 0, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreen2), 0, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("兼課", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("最高學歷", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^Y$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^待查詢$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^無$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^外國$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^國立$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^歐洲$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^亞洲$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^美洲$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^非洲$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("^大洋洲$", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("肄業", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("學分班", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)
flag_person$err_bdegreen2 <- if_else(grepl("結業", flag_person$bdegreen2), 1, flag_person$err_bdegreen2)

#學士學位畢業學校（二）
flag_person$err_bdegreeu2 <- 1
flag_person$err_bdegreeu2 <- if_else(grepl("大學", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("分校", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("學院", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("師大", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("科大", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("教大", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("學校", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("官校", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("預校", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("書院", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("體院", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("師院", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("專科", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("藝專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("海專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("工專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("護專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("家專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("商專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("行專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("農專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("體專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("師專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("藥專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("醫專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("語專", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("士校", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("專校$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("逕讀", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("音樂院$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
#flag_person$err_bdegreeu2 <- if_else(grepl("音樂研究所$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("university", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("University", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("UNIVERSITY", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Uni$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("college", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("College", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("COLLEGE", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Universidad", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("UNIVERSIDAD", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Conservatory", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("CRD", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("ENM", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("CRC", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("EMMA", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("CRR", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("CNR", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("TheNewSchool", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Hochschule", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Universitat", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("StellenboschUni$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^TUDarmstadt$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("大?$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^中興法商$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^N$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^待查詢$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^無$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("離職", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("因故", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("VirginiaMilitaryInstitute", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^LISAA$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^IstitutoSecoli$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^輔大$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^UnivstersityOFDelaware$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^UinvofCentralOklahoma$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^赫拉德茨克拉洛韋$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^ConservatorioStatalediMilano“GiuseppeVerdi”Italia$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^陸軍官校專科班$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("中興法商", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("國立體院", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("逕獨碩士", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("UNISA", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("Univerity", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("山口?立大?", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("ColumbiaBiblicalSeminaryandSchoolofMissions", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("本國", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("肄業", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("學分班", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("結業", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("籌備處$", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^教育學院$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^高雄餐旅$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^台灣體大$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^國立空大$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^台灣體院$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^CityandGuildsofLondonArtSchool$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^BirminghamUiversity$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^NewJerseyInstituteofTechnology$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^CollegeofEducationPotchefstroomSA$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^?校法人????園?????????????西$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^同等學力$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^政戰正規班$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^日本國立埼玉大學$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^日本國立埼玉大學教養學部$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^日本國立奈良教育大學（學院）$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^日本國立熊本大學$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("^ConservatoriostatalediMilano“GiuseppeVerdi”Italia$", flag_person$bdegreeu2), 0, flag_person$err_bdegreeu2)
flag_person$err_bdegreeu2 <- if_else(grepl("所", flag_person$bdegreeu2), 1, flag_person$err_bdegreeu2)

#學士學位畢業系所（二）
flag_person$err_bdegreeg2 <- 0
flag_person$err_bdegreeg2 <- if_else(grepl("博士", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("碩士", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreeg2), 0, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^學士$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("副學士", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("大學", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("分校", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^學院$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("科大", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("學校", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("官校", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("預校", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("書院", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("專科", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("藝專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("海專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("工專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("護專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("家專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("商專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("行專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("農專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("體專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("藥專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("師專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("醫專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("語專", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("university", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("University", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("UNIVERSITY", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("college", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("College", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("COLLEGE", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("兼課", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("最高學歷", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^Y$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^待查詢$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^無$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^逕獨碩士$", flag_person$bdegreeg2), 0, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^逕行修讀碩士$", flag_person$bdegreeg2), 0, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("肄業", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("學分班", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("結業", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("行政$", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("所", flag_person$bdegreeg2), 1, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(grepl("^逕讀碩士$", flag_person$bdegreeg2), 0, flag_person$err_bdegreeg2)

#副學士學位畢業學校國別（一）
flag_person$err_adegreen1 <- 0
flag_person$err_adegreen1 <- if_else(grepl("博士", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("碩士", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("學士", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("副學士", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("大學", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("分校", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("學院", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("科大", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("學校", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("官校", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("預校", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("書院", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("專科", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("藝專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("海專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("工專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("護專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("家專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("商專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("行專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("農專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("體專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("藥專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("師專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("醫專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("語專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("企專", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("university", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("University", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("UNIVERSITY", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("college", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("College", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("COLLEGE", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("系", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("所", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("班$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("不分科系", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("不分系", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("department", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("Department", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("DEPARTMENT", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("兼課", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("最高學歷", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("逕讀", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^Y$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^待查詢$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^無$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^外國$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^國立$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^歐洲$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^亞洲$", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("^同等學力$", flag_person$adegreen1), 0, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("肄業", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("學分班", flag_person$adegreen1), 1, flag_person$err_adegreen1)
flag_person$err_adegreen1 <- if_else(grepl("結業", flag_person$adegreen1), 1, flag_person$err_adegreen1)

#副學士學位畢業學校（一）
flag_person$err_adegreeu1 <- 1
flag_person$err_adegreeu1 <- if_else(grepl("大學", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("分校", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("學院", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("師大", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("科大", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("學校", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("官校", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("預校", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("書院", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("體院", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("專科", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("藝專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("海專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("工專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("護專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("家專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("商專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("行專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("農專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("體專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("藥專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("師專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("醫專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("語專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("企專", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("士校", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("專校$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("逕讀", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("音樂院$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
#flag_person$err_adegreeu1 <- if_else(grepl("音樂研究所$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("university", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("University", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("UNIVERSITY", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("Uni$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("college", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("College", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("COLLEGE", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("Universidad", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("UNIVERSIDAD", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("Conservatory", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("CRD", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("ENM", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("CRC", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("EMMA", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("CRR", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("CNR", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("TheNewSchool", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("Hochschule", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("Universitat", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("^TUDarmstadt$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("^N$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("^待查詢$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("職業學校", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("職校", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高級", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高職", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高工", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高商", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("高農", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("商工", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("工商", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("工家", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("農工", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("工農", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("家商", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("商海", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("海事", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("護家", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("藝校", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("附工", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("附中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("中學", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("一中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("二中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("女中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("實中", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("實驗學校", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("特殊學校", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("亞洲餐旅", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("^高雄餐旅$", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("^珠海學校$", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("本國", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("肄業", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("學分班", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("結業", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
#"仁德醫護管理專科學校"的前身
flag_person$err_adegreeu1 <- if_else(grepl("^仁德高級醫事職業學校$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
#"慈惠醫護管理專科學校"的前身
flag_person$err_adegreeu1 <- if_else(grepl("^私立慈惠謢理助產學校$", flag_person$adegreeu1), 0, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("籌備處$", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)
flag_person$err_adegreeu1 <- if_else(grepl("所", flag_person$adegreeu1), 1, flag_person$err_adegreeu1)

#副學士學位畢業系所（一）
flag_person$err_adegreeg1 <- 0
flag_person$err_adegreeg1 <- if_else(grepl("博士", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("碩士", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("學士", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^副學士$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("大學", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("分校", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^學院$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("科大", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("學校", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("官校", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("預校", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("書院", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("專科", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
#陸軍官校有"專科班"
flag_person$err_adegreeg1 <- if_else((grepl("專科", flag_person$adegreeg1) | grepl("專科班", flag_person$adegreeg1)) & grepl("陸軍官校", flag_person$adegreeu1), 0, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("藝專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("海專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("工專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("護專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("家專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("商專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("行專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("農專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("體專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("藥專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("師專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("醫專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("語專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("企專", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("university", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("University", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("UNIVERSITY", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("college", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("College", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("COLLEGE", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("兼課", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("最高學歷", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("逕讀", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^Y$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^待查詢$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^無$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("^同等學力$", flag_person$adegreeg1), 0, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("肄業", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("學分班", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("結業", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("行政$", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(grepl("所", flag_person$adegreeg1), 1, flag_person$err_adegreeg1)

#副學士學位畢業學校國別（二）
flag_person$err_adegreen2 <- 0
flag_person$err_adegreen2 <- if_else(grepl("博士", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("碩士", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("學士", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("副學士", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("大學", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("分校", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("學院", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("科大", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("學校", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("官校", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("預校", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("書院", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("專科", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("藝專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("海專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("工專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("護專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("家專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("商專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("行專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("農專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("體專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("藥專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("師專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("醫專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("語專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("企專", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("university", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("University", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("UNIVERSITY", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("college", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("College", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("COLLEGE", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("系", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("所", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("班$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("不分科系", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("不分系", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("department", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("Department", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("DEPARTMENT", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("兼課", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("最高學歷", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("逕讀", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^Y$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^待查詢$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^無$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^外國$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^國立$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^歐洲$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^亞洲$", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("^同等學力$", flag_person$adegreen2), 0, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("肄業", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("學分班", flag_person$adegreen2), 1, flag_person$err_adegreen2)
flag_person$err_adegreen2 <- if_else(grepl("結業", flag_person$adegreen2), 1, flag_person$err_adegreen2)

#副學士學位畢業學校（二）
flag_person$err_adegreeu2 <- 1
flag_person$err_adegreeu2 <- if_else(grepl("大學", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("分校", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("學院", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("師大", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("科大", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("學校", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("官校", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("預校", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("書院", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("體院", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("專科", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("藝專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("海專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("工專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("護專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("家專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("商專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("行專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("農專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("體專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("藥專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("師專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("醫專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("語專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("企專", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("士校", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("專校$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("逕讀", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("音樂院$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
#flag_person$err_adegreeu2 <- if_else(grepl("音樂研究所$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("university", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("University", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("UNIVERSITY", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("Uni$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("college", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("College", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("COLLEGE", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("Universidad", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("UNIVERSIDAD", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("Conservatory", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("CRD", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("ENM", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("CRC", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("EMMA", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("CRR", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("CNR", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("TheNewSchool", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("Hochschule", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("BergenSchoolofArchitecture", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("Universitat", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("^TUDarmstadt$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("^N$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("^待查詢$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("職業學校", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("職校", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高級", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高職", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高工", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高商", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("高農", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("商工", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("工商", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("工家", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("農工", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("工農", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("家商", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("商海", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("海事", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("護家", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("藝校", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("附工", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("附中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("中學", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("一中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("二中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("女中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("實中", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("實驗學校", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("特殊學校", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("亞洲餐旅", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("^高雄餐旅$", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("^珠海學校$", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("本國", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("肄業", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("學分班", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("結業", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
#"仁德醫護管理專科學校"的前身
flag_person$err_adegreeu2 <- if_else(grepl("^仁德高級醫事職業學校$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
#"慈惠醫護管理專科學校"的前身
flag_person$err_adegreeu2 <- if_else(grepl("^私立慈惠謢理助產學校$", flag_person$adegreeu2), 0, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("籌備處$", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)
flag_person$err_adegreeu2 <- if_else(grepl("所", flag_person$adegreeu2), 1, flag_person$err_adegreeu2)

#副學士學位畢業系所（二）
flag_person$err_adegreeg2 <- 0
flag_person$err_adegreeg2 <- if_else(grepl("博士", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("碩士", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("學士", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^副學士$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("大學", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("分校", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^學院$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("科大", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("學校", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("官校", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("預校", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("書院", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("專科", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
#陸軍官校有"專科班"
flag_person$err_adegreeg2 <- if_else((grepl("專科", flag_person$adegreeg2) | grepl("專科班", flag_person$adegreeg2)) & grepl("陸軍官校", flag_person$adegreeu1), 0, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("藝專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("海專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("工專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("護專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("家專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("商專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("行專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("農專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("體專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("藥專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("師專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("醫專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("語專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("企專", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("university", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("University", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("UNIVERSITY", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("college", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("College", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("COLLEGE", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("兼課", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("最高學歷", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("逕讀", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^Y$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^待查詢$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^無$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("^同等學力$", flag_person$adegreeg2), 0, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("肄業", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("學分班", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("結業", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("行政$", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(grepl("所", flag_person$adegreeg2), 1, flag_person$err_adegreeg2)

#學校名稱與科系名稱相同之情形
flag_person$err_ddegreeg1 <- if_else(flag_person$ddegreeu1 == flag_person$ddegreeg1 & (flag_person$ddegreeu1 != "N" & flag_person$ddegreeu1 != "逕讀碩士" & flag_person$ddegreeu1 != "逕讀博士"), 1, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg2 <- if_else(flag_person$ddegreeu2 == flag_person$ddegreeg2 & (flag_person$ddegreeu2 != "N" & flag_person$ddegreeu2 != "逕讀碩士" & flag_person$ddegreeu2 != "逕讀博士"), 1, flag_person$err_ddegreeg2)
flag_person$err_mdegreeg1 <- if_else(flag_person$mdegreeu1 == flag_person$mdegreeg1 & (flag_person$mdegreeu1 != "N" & flag_person$mdegreeu1 != "逕讀碩士" & flag_person$mdegreeu1 != "逕讀博士"), 1, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg2 <- if_else(flag_person$mdegreeu2 == flag_person$mdegreeg2 & (flag_person$mdegreeu2 != "N" & flag_person$mdegreeu2 != "逕讀碩士" & flag_person$mdegreeu2 != "逕讀博士"), 1, flag_person$err_mdegreeg2)
flag_person$err_bdegreeg1 <- if_else(flag_person$bdegreeu1 == flag_person$bdegreeg1 & (flag_person$bdegreeu1 != "N" & flag_person$bdegreeu1 != "逕讀碩士" & flag_person$bdegreeu1 != "逕行修讀碩士" & flag_person$bdegreeu1 != "逕讀博士"), 1, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg2 <- if_else(flag_person$bdegreeu2 == flag_person$bdegreeg2 & (flag_person$bdegreeu2 != "N" & flag_person$bdegreeu2 != "逕讀碩士" & flag_person$bdegreeu2 != "逕讀博士"), 1, flag_person$err_bdegreeg2)
flag_person$err_adegreeg1 <- if_else(flag_person$adegreeu1 == flag_person$adegreeg1 & (flag_person$adegreeu1 != "N" & flag_person$adegreeu1 != "逕讀碩士" & flag_person$adegreeu1 != "逕讀博士"), 1, flag_person$err_adegreeg1)
flag_person$err_adegreeg2 <- if_else(flag_person$adegreeu2 == flag_person$adegreeg2 & (flag_person$adegreeu2 != "N" & flag_person$adegreeu2 != "逕讀碩士" & flag_person$adegreeu2 != "逕讀博士"), 1, flag_person$err_adegreeg2)

#軍校當時沒有區分系所
flag_person$err_ddegreeg1 <- if_else(flag_person$ddegreeu1 == flag_person$ddegreeg1 & flag_person$ddegreeg1 == "海軍軍官學校", 0, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg1 <- if_else(flag_person$ddegreeu1 == flag_person$ddegreeg1 & flag_person$ddegreeg1 == "空軍航空技術學院", 0, flag_person$err_ddegreeg1)
flag_person$err_ddegreeg2 <- if_else(flag_person$ddegreeu1 == flag_person$ddegreeg2 & flag_person$ddegreeg2 == "海軍軍官學校", 0, flag_person$err_ddegreeg2)
flag_person$err_ddegreeg2 <- if_else(flag_person$ddegreeu1 == flag_person$ddegreeg2 & flag_person$ddegreeg2 == "空軍航空技術學院", 0, flag_person$err_ddegreeg2)
flag_person$err_mdegreeg1 <- if_else(flag_person$mdegreeu1 == flag_person$mdegreeg1 & flag_person$mdegreeg1 == "海軍軍官學校", 0, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg1 <- if_else(flag_person$mdegreeu1 == flag_person$mdegreeg1 & flag_person$mdegreeg1 == "空軍航空技術學院", 0, flag_person$err_mdegreeg1)
flag_person$err_mdegreeg2 <- if_else(flag_person$mdegreeu1 == flag_person$mdegreeg2 & flag_person$mdegreeg2 == "海軍軍官學校", 0, flag_person$err_mdegreeg2)
flag_person$err_mdegreeg2 <- if_else(flag_person$mdegreeu1 == flag_person$mdegreeg2 & flag_person$mdegreeg2 == "空軍航空技術學院", 0, flag_person$err_mdegreeg2)
flag_person$err_bdegreeg1 <- if_else(flag_person$bdegreeu1 == flag_person$bdegreeg1 & flag_person$bdegreeg1 == "海軍軍官學校", 0, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg1 <- if_else(flag_person$bdegreeu1 == flag_person$bdegreeg1 & flag_person$bdegreeg1 == "空軍航空技術學院", 0, flag_person$err_bdegreeg1)
flag_person$err_bdegreeg2 <- if_else(flag_person$bdegreeu1 == flag_person$bdegreeg2 & flag_person$bdegreeg2 == "海軍軍官學校", 0, flag_person$err_bdegreeg2)
flag_person$err_bdegreeg2 <- if_else(flag_person$bdegreeu1 == flag_person$bdegreeg2 & flag_person$bdegreeg2 == "空軍航空技術學院", 0, flag_person$err_bdegreeg2)
flag_person$err_adegreeg1 <- if_else(flag_person$adegreeu1 == flag_person$adegreeg1 & flag_person$adegreeg1 == "海軍軍官學校", 0, flag_person$err_adegreeg1)
flag_person$err_adegreeg1 <- if_else(flag_person$adegreeu1 == flag_person$adegreeg1 & flag_person$adegreeg1 == "空軍航空技術學院", 0, flag_person$err_adegreeg1)
flag_person$err_adegreeg2 <- if_else(flag_person$adegreeu1 == flag_person$adegreeg2 & flag_person$adegreeg2 == "海軍軍官學校", 0, flag_person$err_adegreeg2)
flag_person$err_adegreeg2 <- if_else(flag_person$adegreeu1 == flag_person$adegreeg2 & flag_person$adegreeg2 == "空軍航空技術學院", 0, flag_person$err_adegreeg2)

#學士逕讀碩士，但副學士為N
flag_person$err_bdeade <- 0
flag_person$err_bdeade <- if_else(flag_person$bdegreeu1 == "逕讀碩士" & flag_person$adegreeu1 == "N", 1, flag_person$err_bdeade)
flag_person$err_bdeade <- if_else(flag_person$bdegreeu1 == "逕讀" & flag_person$adegreeu1 == "N", 1, flag_person$err_bdeade)
flag_person$err_bdeade <- if_else(grepl("讀", flag_person$bdegreeu1) & flag_person$adegreeu1 == "N", 1, flag_person$err_bdeade)

#碩士逕讀碩士，但學士為N
flag_person$err_bdeade2 <- 0
flag_person$err_bdeade2 <- if_else(flag_person$mdegreeu1 == "逕讀博士" & flag_person$bdegreeu1 == "N", 1, flag_person$err_bdeade2)
flag_person$err_bdeade2 <- if_else(flag_person$mdegreeu1 == "逕讀" & flag_person$bdegreeu1 == "N", 1, flag_person$err_bdeade2)

#碩士、學士逕讀博士，直接有博士
flag_person$err_bdeade3 <- 0
flag_person$err_bdeade3 <- if_else(flag_person$mdegreeu1 == "逕讀博士" & flag_person$bdegreeu1 == "逕讀博士", 1, flag_person$err_bdeade3)
flag_person$err_bdeade3 <- if_else(flag_person$mdegreeu1 == "逕讀" & flag_person$bdegreeu1 == "逕讀", 1, flag_person$err_bdeade3)

flag_person$err_bdeade <- if_else(flag_person$err_bdeade3 == 1 & flag_person$err_bdeade == 1, 0, flag_person$err_bdeade)

#有副學士，學士填逕讀碩士，但碩士為N
flag_person$err_bdeade6 <- 0
flag_person$err_bdeade6 <- if_else(flag_person$adegreeu1 != "N" & grepl("讀", flag_person$bdegreeu1) & flag_person$mdegreeu1 == "N", 1, flag_person$err_bdeade6)

#有學士，碩士填逕讀博士，但博士為N
flag_person$err_bdeade7 <- 0
flag_person$err_bdeade7 <- if_else(flag_person$bdegreeu1 != "N" & grepl("讀", flag_person$mdegreeu1) & flag_person$ddegreeu1 == "N", 1, flag_person$err_bdeade7)


#學校為國外學校，但國別卻填本國
flag_person$err_bdeade4 <- 0
#博士(一)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("A", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("E", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("I", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("O", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("U", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("a", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("e", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("i", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("o", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("u", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^英國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^美國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^加拿大", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^日本", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^韓國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^菲律賓", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^南非", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^西班牙", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^法國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^俄羅斯", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^德國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^澳洲", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^紐西蘭", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^義大利", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^比利時", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^芬蘭", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^澳大利亞", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^泰國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^美利堅合眾國", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^印尼", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^阿根廷", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^越南", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^香港", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="英國" & grepl("^彰化", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^澳大利亞", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("^荷蘭", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("紐約", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("州立", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("東京", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("波士頓", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("路易安納", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("關西", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("專修大學", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("匹茲堡", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("俄克拉荷馬", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("雪菲爾", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen1=="本國" & grepl("胡志明", flag_person$ddegreeu1), 1, flag_person$err_bdeade4)
#博士(二)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("A", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("E", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("I", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("O", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("U", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("a", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("e", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("i", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("o", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("u", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^英國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^美國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^加拿大", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^日本", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^韓國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^菲律賓", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^南非", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^西班牙", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^法國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^俄羅斯", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^德國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^澳洲", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^紐西蘭", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^義大利", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^比利時", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^芬蘭", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^澳大利亞", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^泰國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^美利堅合眾國", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^印尼", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^阿根廷", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^越南", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^香港", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="英國" & grepl("^彰化", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^澳大利亞", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("^荷蘭", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("紐約", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("州立", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("東京", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("波士頓", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("路易安納", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("關西", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("專修大學", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("匹茲堡", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("俄克拉荷馬", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("雪菲爾", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$ddegreen2=="本國" & grepl("胡志明", flag_person$ddegreeu2), 1, flag_person$err_bdeade4)
#碩士(一)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("A", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("E", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("I", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("O", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("U", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("a", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("e", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("i", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("o", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("u", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^英國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^美國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^加拿大", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^日本", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^韓國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^菲律賓", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^南非", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^西班牙", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^法國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^俄羅斯", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^德國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^澳洲", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^紐西蘭", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^義大利", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^比利時", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^芬蘭", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^澳大利亞", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^泰國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^美利堅合眾國", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^印尼", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^阿根廷", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^越南", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^香港", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="英國" & grepl("^彰化", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^澳大利亞", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("^荷蘭", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("紐約", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("州立", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("東京", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("波士頓", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("路易安納", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("關西", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("專修大學", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("匹茲堡", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("俄克拉荷馬", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("雪菲爾", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen1=="本國" & grepl("胡志明", flag_person$mdegreeu1), 1, flag_person$err_bdeade4)
#碩士(二)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("A", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("E", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("I", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("O", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("U", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("a", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("e", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("i", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("o", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("u", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^英國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^美國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^加拿大", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^日本", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^韓國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^菲律賓", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^南非", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^西班牙", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^法國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^俄羅斯", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^德國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^澳洲", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^紐西蘭", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^義大利", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^比利時", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^芬蘭", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^澳大利亞", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^泰國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^美利堅合眾國", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^印尼", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^阿根廷", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^越南", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^香港", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="英國" & grepl("^彰化", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^澳大利亞", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("^荷蘭", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("紐約", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("州立", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("東京", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("波士頓", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("路易安納", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("關西", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("專修大學", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("匹茲堡", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("俄克拉荷馬", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("雪菲爾", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$mdegreen2=="本國" & grepl("胡志明", flag_person$mdegreeu2), 1, flag_person$err_bdeade4)
#學士(一)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("A", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("E", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("I", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("O", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("U", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("a", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("e", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("i", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("o", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("u", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^英國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^美國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^加拿大", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^日本", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^韓國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^菲律賓", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^南非", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^西班牙", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^法國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^俄羅斯", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^德國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^澳洲", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^紐西蘭", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^義大利", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^比利時", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^芬蘭", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^澳大利亞", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^泰國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^美利堅合眾國", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^印尼", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^阿根廷", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^越南", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^香港", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="英國" & grepl("^彰化", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^澳大利亞", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("^荷蘭", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("紐約", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("州立", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("東京", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("波士頓", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("路易安納", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("關西", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("專修大學", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("匹茲堡", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("俄克拉荷馬", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("雪菲爾", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen1=="本國" & grepl("胡志明", flag_person$bdegreeu1), 1, flag_person$err_bdeade4)
#學士(二)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("A", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("E", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("I", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("O", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("U", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("a", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("e", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("i", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("o", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("u", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^英國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^美國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^加拿大", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^日本", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^韓國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^菲律賓", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^南非", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^西班牙", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^法國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^俄羅斯", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^德國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^澳洲", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^紐西蘭", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^義大利", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^比利時", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^芬蘭", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^澳大利亞", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^泰國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^美利堅合眾國", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^印尼", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^阿根廷", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^越南", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^香港", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="英國" & grepl("^彰化", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^澳大利亞", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("^荷蘭", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("紐約", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("州立", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("東京", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("波士頓", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("路易安納", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("關西", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("專修大學", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("匹茲堡", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("俄克拉荷馬", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("雪菲爾", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$bdegreen2=="本國" & grepl("胡志明", flag_person$bdegreeu2), 1, flag_person$err_bdeade4)
#副學士(一)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("A", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("E", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("I", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("O", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("U", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("a", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("e", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("i", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("o", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen1=="本國" & grepl("u", flag_person$adegreeu1), 1, flag_person$err_bdeade4)
#副學士(二)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("A", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("E", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("I", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("O", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("U", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("a", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("e", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("i", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("o", flag_person$adegreeu2), 1, flag_person$err_bdeade4)
flag_person$err_bdeade4 <- if_else(flag_person$adegreen2=="本國" & grepl("u", flag_person$adegreeu2), 1, flag_person$err_bdeade4)

#逕讀碩士國別填本國
flag_person$err_bdeade5 <- 0
flag_person$err_bdeade5 <- if_else(flag_person$bdegreeu1 == "逕讀碩士" & grepl("國", flag_person$bdegreen1), 1, flag_person$err_bdeade5)

flag_person$err_flag_sp6 <- flag_person$err_ddegreen1 + flag_person$err_ddegreeu1 + flag_person$err_ddegreeg1 + flag_person$err_ddegreen2 + flag_person$err_ddegreeu2 + flag_person$err_ddegreeg2 + flag_person$err_mdegreen1 + flag_person$err_mdegreeu1 + flag_person$err_mdegreeg1 + flag_person$err_mdegreen2 + flag_person$err_mdegreeu2 + flag_person$err_mdegreeg2 + flag_person$err_bdegreen1 + flag_person$err_bdegreeu1 + flag_person$err_bdegreeg1 + flag_person$err_bdegreen2 + flag_person$err_bdegreeu2 + flag_person$err_bdegreeg2 + flag_person$err_adegreen1 + flag_person$err_adegreeu1 + flag_person$err_adegreeg1 + flag_person$err_adegreen2 + flag_person$err_adegreeu2 + flag_person$err_adegreeg2 + flag_person$err_bdeade + flag_person$err_bdeade2 + flag_person$err_bdeade3 + flag_person$err_bdeade4 + flag_person$err_bdeade5+ flag_person$err_bdeade6+ flag_person$err_bdeade7

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$err_flag_sp6 != 0, 1, flag_person$err_flag)

#兼任或鐘點教師，次高學歷可不填

#最高學歷為碩士，但沒填學士學歷
flag_person$err_flag <- if_else(flag_person$source == 1 & (flag_person$emptype == "長期代課" | flag_person$emptype == "兼任" | flag_person$emptype == "鐘點教師") & flag_person$mdegreen1 != "" & (flag_person$bdegreen1 == "NA" | flag_person$bdegreen1 == "無法取得資料" | flag_person$bdegreen1 == "待查詢" ), 0, flag_person$err_flag)
#最高學歷為博士，但沒填學士學歷
flag_person$err_flag <- if_else(flag_person$source == 1 & (flag_person$emptype == "長期代課" | flag_person$emptype == "兼任" | flag_person$emptype == "鐘點教師") & flag_person$ddegreen1 != "" & (flag_person$bdegreen1 == "NA" | flag_person$bdegreen1 == "無法取得資料" | flag_person$bdegreen1 == "待查詢" ), 0, flag_person$err_flag)
#最高學歷為博士，但沒填碩士學歷
flag_person$err_flag <- if_else(flag_person$source == 1 & (flag_person$emptype == "長期代課" | flag_person$emptype == "兼任" | flag_person$emptype == "鐘點教師") & flag_person$ddegreen1 != "" & (flag_person$mdegreen1 == "NA" | flag_person$mdegreen1 == "無法取得資料" | flag_person$mdegreen1 == "待查詢" ), 0, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（", sep = "")
flag_person$name <- if_else(flag_person$err_ddegreen1 != 0, paste(flag_person$name, "博士學位畢業學校國別（一）：", flag_person$ddegreen1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_ddegreeu1 != 0, paste(flag_person$name, "博士學位畢業學校（一）：", flag_person$ddegreeu1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_ddegreeg1 != 0, paste(flag_person$name, "博士學位畢業系所（一）：", flag_person$ddegreeg1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_ddegreen2 != 0, paste(flag_person$name, "博士學位畢業學校國別（二）：", flag_person$ddegreen2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_ddegreeu2 != 0, paste(flag_person$name, "博士學位畢業學校（二）：", flag_person$ddegreeu2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_ddegreeg2 != 0, paste(flag_person$name, "博士學位畢業系所（二）：", flag_person$ddegreeg2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreen1 != 0, paste(flag_person$name, "碩士學位畢業學校國別（一）：", flag_person$mdegreen1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreeu1 != 0, paste(flag_person$name, "碩士學位畢業學校（一）：", flag_person$mdegreeu1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreeg1 != 0, paste(flag_person$name, "碩士學位畢業系所（一）：", flag_person$mdegreeg1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreen2 != 0, paste(flag_person$name, "碩士學位畢業學校國別（二）：", flag_person$mdegreen2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreeu2 != 0, paste(flag_person$name, "碩士學位畢業學校（二）：", flag_person$mdegreeu2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_mdegreeg2 != 0, paste(flag_person$name, "碩士學位畢業系所（二）：", flag_person$mdegreeg2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreen1 != 0, paste(flag_person$name, "學士學位畢業學校國別（一）：", flag_person$bdegreen1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreeu1 != 0, paste(flag_person$name, "學士學位畢業學校（一）：", flag_person$bdegreeu1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreeg1 != 0, paste(flag_person$name, "學士學位畢業科系（一）：", flag_person$bdegreeg1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreen2 != 0, paste(flag_person$name, "學士學位畢業學校國別（二）：", flag_person$bdegreen2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreeu2 != 0, paste(flag_person$name, "學士學位畢業學校（二）：", flag_person$bdegreeu2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdegreeg2 != 0, paste(flag_person$name, "學士學位畢業科系（二）：", flag_person$bdegreeg2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreen1 != 0, paste(flag_person$name, "副學士或專科畢業學校國別（一）：", flag_person$adegreen1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreeu1 != 0, paste(flag_person$name, "副學士或專科畢業學校（一）：", flag_person$adegreeu1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreeg1 != 0, paste(flag_person$name, "副學士或專科畢業科系（一）：", flag_person$adegreeg1, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreen2 != 0, paste(flag_person$name, "副學士或專科畢業學校國別（二）：", flag_person$adegreen2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreeu2 != 0, paste(flag_person$name, "副學士或專科畢業學校（二）：", flag_person$adegreeu2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_adegreeg2 != 0, paste(flag_person$name, "副學士或專科畢業科系（二）：", flag_person$adegreeg2, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade != 0, paste(flag_person$name, "副學士或專科畢業學校國別（一）：", flag_person$adegreen1, "、副學士或專科畢業學校（一）：", flag_person$adegreeu1, "、副學士或專科畢業科系（一）：",  flag_person$adegreeg1, " (若逕讀碩士，副學士或專科畢業資訊應不為N)", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade2 != 0, paste(flag_person$name, "(若逕讀博士，學士畢業資訊應不為N)", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade3 != 0, paste(flag_person$name, "(若逕讀博士，學士或專科畢業資訊應不為逕讀博士)", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade4 != 0, paste(flag_person$name, "若於外國學校取得學位，其學位畢業學校國別不應為本國", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade5 != 0, paste(flag_person$name, "若為逕讀碩士，相關欄位請依欄位說明填寫", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade6 != 0, paste(flag_person$name, "若為逕讀碩士，應填列碩士學歷相關資訊", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_bdeade7 != 0, paste(flag_person$name, "若為逕讀博士，應填列博士學歷相關資訊", sep = ""), flag_person$name)
flag_person$name <- paste(flag_person$name, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

# （請確認畢業科系正確名稱）
# （請確認畢業系所正確名稱）
# （請確認畢業學校正確名稱）
# （請依照*員『*士』學位畢業證書，填寫正確之學校名稱。）
# （請依照*員『*士』學位畢業證書，填寫正確之系所名稱。）
# （請依照*員『*士』學位畢業證書，填寫正確之科系名稱。）
# （請確認*員畢業學校正確名稱及拼字是否正確）
# （請依照上開人員碩士學位畢業證書，填寫正確之系所名稱全稱。）
# 
# 40學分班之文字
# （學分班非屬『學位授予法』規定之學位別，且依該法規定，須修業期滿、修滿應修學分並符畢業條件，始能獲頒學位。若*員經確認未獲碩士學位，請於碩士學位畢業學校國別、畢業學校、畢業系所三欄填『N』）
# （學分班非屬『學位授予法』規定之學位別，且依該法規定，須修業期滿、修滿應修學分並符畢業條件，始能獲頒學位。若*員經確認未獲學士學位，請於學士學位畢業學校國別、畢業學校、畢業科系三欄填『N』）

#高中學歷
# （請確認*員最高學歷，若*員最高學歷不為大專以上，「最高學歷是否為大專以上」及各級學歷資訊欄位請皆填「N」。）

#逕讀碩士
#（請確認並修正張員之學士學位各欄位資訊，若張員以副學士學位或專科學歷，就讀研究所取得碩士學位，則學士學位相關欄位資料，請直接填寫「逕讀碩士」）


#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_spe6 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_spe6)[3 : length(colnames(flag_person_wide_spe6))]
flag_person_wide_spe6$spe6_r <- NA
for (i in temp){
  flag_person_wide_spe6$spe6_r <- paste(flag_person_wide_spe6$spe6_r, flag_person_wide_spe6[[i]], sep = " ")
}
flag_person_wide_spe6$spe6_r <- gsub("NA ", replacement="", flag_person_wide_spe6$spe6_r)
flag_person_wide_spe6$spe6_r <- gsub(" NA", replacement="", flag_person_wide_spe6$spe6_r)

#產生檢誤報告文字
spe6_temp <- flag_person_wide_spe6 %>%
  group_by(organization_id) %>%
  mutate(spe6_txt = paste(source, "之大學（學士）以上各教育階段學歷資料不完整或不正確：", spe6_r, sep = ""), "") %>%
  subset(select = c(organization_id, spe6_txt)) %>%
  distinct(organization_id, spe6_txt)

#根據organization_id，展開成寬資料(wide)
spe6 <- spe6_temp %>%
  dcast(organization_id ~ spe6_txt, value.var = "spe6_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(spe6)[2 : length(colnames(spe6))]
spe6$spe6 <- NA
for (i in temp){
  spe6$spe6 <- paste(spe6$spe6, spe6[[i]], sep = "； ")
}
spe6$spe6 <- gsub("NA； ", replacement="", spe6$spe6)
spe6$spe6 <- gsub("； NA", replacement="", spe6$spe6)

#產生檢誤報告文字
spe6 <- spe6 %>%
  subset(select = c(organization_id, spe6)) %>%
  distinct(organization_id, spe6)
}else{
#偵測spe6是否存在。若不存在，則產生NA行
if('spe6' %in% ls()){
  print("spe6")
}else{
  spe6 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  spe6$spe6 <- ""
}
}
# flag83: 離退教職員（工）資料表所列人員，不應填列為本次教員資料表或職員（工）資料表之專任或代理人員。 -------------------------------------------------------------------
flag_person <- drev_P_retire %>%
  rename(name = name.x, name_retire = name.y)

#若drev_P_retire無資料，建立物件
if (dim(drev_P_retire)[1] == 0) {
  temp <- matrix("", nrow = 1, ncol = ncol(flag_person)) %>% data.frame()
  names(temp) <- names(flag_person)
  flag_person <- temp
} else{
  print("flag83: drev_P_retire is already exists.")
}

#離退教職員(工)資料表所列人員，不應填列為本次教員資料表或職員（工）資料表之專任或代理人員。(與本期資料比對)
#抓出:離退人員有出現在教員資料表、職員工資料表，且為專任或代理
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(!is.na(flag_person$name_retire) 
                                & flag_person$emptype %in% c("專任", "代理", "代理(連)"), 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag83 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag83)[3 : length(colnames(flag_person_wide_flag83))]
flag_person_wide_flag83$flag83_r <- NA
for (i in temp){
  flag_person_wide_flag83$flag83_r <- paste(flag_person_wide_flag83$flag83_r, flag_person_wide_flag83[[i]], sep = " ")
}
flag_person_wide_flag83$flag83_r <- gsub("NA ", replacement="", flag_person_wide_flag83$flag83_r)
flag_person_wide_flag83$flag83_r <- gsub(" NA", replacement="", flag_person_wide_flag83$flag83_r)

#產生檢誤報告文字
flag83_temp <- flag_person_wide_flag83 %>%
  group_by(organization_id) %>%
  mutate(flag83_txt = paste(source, "：", flag83_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag83_txt)) %>%
  distinct(organization_id, flag83_txt)

#根據organization_id，展開成寬資料(wide)
flag83 <- flag83_temp %>%
  dcast(organization_id ~ flag83_txt, value.var = "flag83_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag83)[2 : length(colnames(flag83))]
flag83$flag83 <- NA
for (i in temp){
  flag83$flag83 <- paste(flag83$flag83, flag83[[i]], sep = "； ")
}
flag83$flag83 <- gsub("NA； ", replacement="", flag83$flag83)
flag83$flag83 <- gsub("； NA", replacement="", flag83$flag83)

#產生檢誤報告文字
flag83 <- flag83 %>%
  subset(select = c(organization_id, flag83)) %>%
  distinct(organization_id, flag83) %>%
  mutate(flag83 = paste(flag83, "（請確認上述人員是否退休、退伍或因故離職，若是，則不需填列至本次教員資料表或職員（工）資料表，並請務必依欄位說明確認離退職類別）", sep = ""))
}else{
#偵測flag83是否存在。若不存在，則產生NA行
if('flag83' %in% ls()){
  print("flag83")
}else{
  flag83 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag83$flag83 <- ""
}
}
# flag92: 教員/職員（工）資料表及離退教職員(工)資料表，同一身分識別碼所對應的姓名不一致，請確認各該身分識別碼所屬正確人員。 -------------------------------------------------------------------
flag_person <- drev_P_retire %>%
  rename(name = name.x, name_retire = name.y)

#若drev_P_retire無資料，建立物件
if (dim(drev_P_retire)[1] == 0) {
  temp <- matrix("", nrow = 1, ncol = ncol(flag_person)) %>% data.frame()
  names(temp) <- names(flag_person)
  flag_person <- temp
} else{
  print("flag92: drev_P_retire is already exists.")
}

#本次離退教職員(工)資料表所列人員，若有出現本次教員資料表或職員（工）資料表(已存在錯誤情形)，姓名不一致
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$name != flag_person$name_retire, 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "/", flag_person$name_retire, sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag92 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag92)[3 : length(colnames(flag_person_wide_flag92))]
flag_person_wide_flag92$flag92_r <- NA
for (i in temp){
  flag_person_wide_flag92$flag92_r <- paste(flag_person_wide_flag92$flag92_r, flag_person_wide_flag92[[i]], sep = " ")
}
flag_person_wide_flag92$flag92_r <- gsub("NA ", replacement="", flag_person_wide_flag92$flag92_r)
flag_person_wide_flag92$flag92_r <- gsub(" NA", replacement="", flag_person_wide_flag92$flag92_r)

#產生檢誤報告文字
flag92_temp <- flag_person_wide_flag92 %>%
  group_by(organization_id) %>%
  mutate(flag92_txt = paste("請確認：", flag92_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag92_txt)) %>%
  distinct(organization_id, flag92_txt)

#根據organization_id，展開成寬資料(wide)
flag92 <- flag92_temp %>%
  dcast(organization_id ~ flag92_txt, value.var = "flag92_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag92)[2 : length(colnames(flag92))]
flag92$flag92 <- NA
for (i in temp){
  flag92$flag92 <- paste(flag92$flag92, flag92[[i]], sep = "； ")
}
flag92$flag92 <- gsub("NA； ", replacement="", flag92$flag92)
flag92$flag92 <- gsub("； NA", replacement="", flag92$flag92)

#產生檢誤報告文字
flag92 <- flag92 %>%
  subset(select = c(organization_id, flag92)) %>%
  distinct(organization_id, flag92) %>%
  mutate(flag92 = paste(flag92, "（教員/職員（工）資料表及離退教職員(工)資料表，同一身分識別碼所對應的姓名不一致，請確認各該身分識別碼所屬正確人員。）", sep = ""))
}else{
#偵測flag92是否存在。若不存在，則產生NA行
if('flag92' %in% ls()){
  print("flag92")
}else{
  flag92 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag92$flag92 <- ""
}
}
# flag84: 離退教職員（工）資料表所列人員，應為上一學年（期）專任教職員（工）。 -------------------------------------------------------------------
flag_person <- drev_P_retire_pre_inner %>%
  rename(name = name.x, name_retire = name.y) %>%
  left_join(edu_name2, by = c("organization_id"))

#若drev_P_retire_pre_inner無資料，建立物件
if (dim(drev_P_retire_pre_inner)[1] == 0) {
  temp <- matrix("", nrow = 1, ncol = ncol(flag_person)) %>% data.frame()
  names(temp) <- names(flag_person)
  flag_person <- temp
} else{
  print("flag84: drev_P_retire_pre_inner is already exists.")
}

#填寫在「離退教職員(工)資料表」之人員，聘任類別需為「專任」。(與上一期資料比對)
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$emptype != "專任" & flag_person$emptype != "", 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag84 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag84)[3 : length(colnames(flag_person_wide_flag84))]
flag_person_wide_flag84$flag84_r <- NA
for (i in temp){
  flag_person_wide_flag84$flag84_r <- paste(flag_person_wide_flag84$flag84_r, flag_person_wide_flag84[[i]], sep = " ")
}
flag_person_wide_flag84$flag84_r <- gsub("NA ", replacement="", flag_person_wide_flag84$flag84_r)
flag_person_wide_flag84$flag84_r <- gsub(" NA", replacement="", flag_person_wide_flag84$flag84_r)

#產生檢誤報告文字
flag84_temp <- flag_person_wide_flag84 %>%
  group_by(organization_id) %>%
  mutate(flag84_txt = paste(source, "：", flag84_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag84_txt)) %>%
  distinct(organization_id, flag84_txt)

#根據organization_id，展開成寬資料(wide)
flag84 <- flag84_temp %>%
  dcast(organization_id ~ flag84_txt, value.var = "flag84_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag84)[2 : length(colnames(flag84))]
flag84$flag84 <- NA
for (i in temp){
  flag84$flag84 <- paste(flag84$flag84, flag84[[i]], sep = "； ")
}
flag84$flag84 <- gsub("NA； ", replacement="", flag84$flag84)
flag84$flag84 <- gsub("； NA", replacement="", flag84$flag84)

#產生檢誤報告文字
flag84 <- flag84 %>%
  subset(select = c(organization_id, flag84)) %>%
  distinct(organization_id, flag84) %>%
  mutate(flag84 = paste(flag84, "（查貴校上一學年所填資料，上述人員聘任類別非屬『專任』。依欄位說明，非專任教職員(工)之退休或離職者，不須填列離退教職員(工)資料表，請務必再確認。）", sep = ""))
}else{
#偵測flag84是否存在。若不存在，則產生NA行
if('flag84' %in% ls()){
  print("flag84")
}else{
  flag84 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag84$flag84 <- ""
}
}
# flag85: 離退教職員（工）資料表中，離職退休情況註記為「退休」人員之年齡偏小。 -------------------------------------------------------------------
flag_person <- drev_P_retire_pre_inner %>%
  rename(name = name.x, name_retire = name.y) %>%
  left_join(edu_name2, by = c("organization_id"))

#若drev_P_retire_pre_inner無資料，建立物件
if (dim(drev_P_retire_pre_inner)[1] == 0) {
  temp <- matrix("", nrow = 1, ncol = ncol(flag_person)) %>% data.frame()
  names(temp) <- names(flag_person)
  flag_person <- temp
} else{
  print("flag85: drev_P_retire_pre_inner is already exists.")
}

#離職退休情況為「退休」之人員年齡低於42歲。(與上一期資料比對)
#年齡
#創設變項出生年月日：birthy birthm birthd
flag_person$birthy <- ""
flag_person$birthm <- ""
flag_person$birthd <- ""

flag_person$birthy <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 1, 2), flag_person$birthy)
flag_person$birthm <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 3, 4), flag_person$birthm)
flag_person$birthd <- if_else(nchar(flag_person$birthdate) == 6, substr(flag_person$birthdate, 5, 6), flag_person$birthd)
flag_person$birthy <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 1, 3), flag_person$birthy)
flag_person$birthm <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 4, 5), flag_person$birthm)
flag_person$birthd <- if_else(nchar(flag_person$birthdate) == 7, substr(flag_person$birthdate, 6, 7), flag_person$birthd)

flag_person$birthy <- as.numeric(flag_person$birthy)
flag_person$birthm <- as.numeric(flag_person$birthm)
flag_person$birthd <- as.numeric(flag_person$birthd)

flag_person$survey_year <- 2023

#創設變項年齡（以年為單位）：age
flag_person$age <- 0
flag_person$age <- if_else(flag_person$survey_year %% 4 != 0, ((flag_person$survey_year-1911) + 9/12 + 30/365) - (flag_person$birthy + (flag_person$birthm/12) + (flag_person$birthd/365)), flag_person$age)
flag_person$age <- if_else(flag_person$survey_year %% 4 == 0, ((flag_person$survey_year-1911) + 9/12 + 30/366) - (flag_person$birthy + (flag_person$birthm/12) + (flag_person$birthd/366)), flag_person$age)


flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$resitu == "R" & flag_person$age < 42, 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag85 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag85)[3 : length(colnames(flag_person_wide_flag85))]
flag_person_wide_flag85$flag85_r <- NA
for (i in temp){
  flag_person_wide_flag85$flag85_r <- paste(flag_person_wide_flag85$flag85_r, flag_person_wide_flag85[[i]], sep = " ")
}
flag_person_wide_flag85$flag85_r <- gsub("NA ", replacement="", flag_person_wide_flag85$flag85_r)
flag_person_wide_flag85$flag85_r <- gsub(" NA", replacement="", flag_person_wide_flag85$flag85_r)

#產生檢誤報告文字
flag85_temp <- flag_person_wide_flag85 %>%
  group_by(organization_id) %>%
  mutate(flag85_txt = paste(source, "：", flag85_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag85_txt)) %>%
  distinct(organization_id, flag85_txt)

#根據organization_id，展開成寬資料(wide)
flag85 <- flag85_temp %>%
  dcast(organization_id ~ flag85_txt, value.var = "flag85_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag85)[2 : length(colnames(flag85))]
flag85$flag85 <- NA
for (i in temp){
  flag85$flag85 <- paste(flag85$flag85, flag85[[i]], sep = "； ")
}
flag85$flag85 <- gsub("NA； ", replacement="", flag85$flag85)
flag85$flag85 <- gsub("； NA", replacement="", flag85$flag85)

#產生檢誤報告文字
flag85 <- flag85 %>%
  subset(select = c(organization_id, flag85)) %>%
  distinct(organization_id, flag85) %>%
  mutate(flag85 = paste(flag85, "（該員年齡似低於最低法定退休年齡，敬請再協助確認）", sep = ""))
}else{
#偵測flag85是否存在。若不存在，則產生NA行
if('flag85' %in% ls()){
  print("flag85")
}else{
  flag85 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag85$flag85 <- ""
}
}
# flag93: 離退教職員（工）資料表所列人員，應為上一學年（期）之教員或職員（工）。 -------------------------------------------------------------------
flag_person <- drev_P_retire_pre_right %>%
  rename(name = name.x, name_retire = name.y) %>%
  left_join(edu_name2, by = c("organization_id"))

#若drev_P_retire_pre_inner無資料，建立物件
if (dim(drev_P_retire_pre_inner)[1] == 0) {
  temp <- matrix("", nrow = 1, ncol = ncol(flag_person)) %>% data.frame()
  names(temp) <- names(flag_person)
  flag_person <- temp
} else{
  print("flag93: drev_P_retire_pre_inner is already exists.")
}

#填寫在「離退教職員(工)資料表」之人員，聘任類別需為「專任」。(與上一期資料比對)
#抓出:離退人員在上一期聘任類別非專任(專任的人員才能填到離退表)
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(is.na(flag_person$pre), 1, flag_person$err_flag)

#若該校上一期未上傳人事資料，此檢誤不檢查
drev_person_pre_list <- drev_person_pre %>%
  select("organization_id") %>%
  distinct(organization_id, .keep_all = TRUE) %>%
  mutate(pre_list = 1)
flag_person <- flag_person %>%
  left_join(drev_person_pre_list, by = "organization_id")

flag_person$err_flag <- if_else(flag_person$err_flag == 1 & is.na(flag_person$pre_list), 0, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name_retire,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id + source，展開成寬資料(wide)
flag_person_wide_flag93 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag93)[3 : length(colnames(flag_person_wide_flag93))]
flag_person_wide_flag93$flag93_r <- NA
for (i in temp){
  flag_person_wide_flag93$flag93_r <- paste(flag_person_wide_flag93$flag93_r, flag_person_wide_flag93[[i]], sep = " ")
}
flag_person_wide_flag93$flag93_r <- gsub("NA ", replacement="", flag_person_wide_flag93$flag93_r)
flag_person_wide_flag93$flag93_r <- gsub(" NA", replacement="", flag_person_wide_flag93$flag93_r)

#產生檢誤報告文字
flag93_temp <- flag_person_wide_flag93 %>%
  group_by(organization_id) %>%
  mutate(flag93_txt = paste("離退教職員(工)資料表：", flag93_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag93_txt)) %>%
  distinct(organization_id, flag93_txt)

#根據organization_id，展開成寬資料(wide)
flag93 <- flag93_temp %>%
  dcast(organization_id ~ flag93_txt, value.var = "flag93_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag93)[2 : length(colnames(flag93))]
flag93$flag93 <- NA
for (i in temp){
  flag93$flag93 <- paste(flag93$flag93, flag93[[i]], sep = "； ")
}
flag93$flag93 <- gsub("NA； ", replacement="", flag93$flag93)
flag93$flag93 <- gsub("； NA", replacement="", flag93$flag93)

#產生檢誤報告文字
flag93 <- flag93 %>%
  subset(select = c(organization_id, flag93)) %>%
  distinct(organization_id, flag93) %>%
  mutate(flag93 = if_else(substr(organization_id, 3, 3) == "1", paste0(flag93, "（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於112年2月1日-112年7月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）"), #私立
                                                                paste0(flag93, "（查貴校上一學年所填資料，上述人員未在貴校教職員(工)資料中，請確認上述人員是否於111年10月1日-112年7月31日有退休或因故離職之情形，或是否屬於貴校教職員(工)，併請確認貴校教職員工名單是否完整正確。）"))) #公立
}else{
#偵測flag93是否存在。若不存在，則產生NA行
if('flag93' %in% ls()){
  print("flag93")
}else{
  flag93 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag93$flag93 <- ""
}
}
# flag86: 上一學年（期）專任教職員（工）若未於本學年（期）教職員（工）資料表內，則應填列於離退教職員（工）資料表。 -------------------------------------------------------------------
flag_person <- drev_P_retire_merge_pre %>%
  rename(name = name.x, name_retire = name, edu_name2 = edu_name2.x)

#抓出:有出現在上一期資料，但在本次填報已被刪除，但退休資料表沒有出現的專任人員
#只出現在上一期(pre = 1 & now = NA)   且為專任    但本次離退表卻沒有出現(空白)(retire = NA)
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$pre == 1 & is.na(flag_person$now) & is.na(flag_person$retire) & flag_person$emptype.y == "專任", 1, flag_person$err_flag)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name.y,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id，展開成寬資料(wide)
flag_person_wide_flag86 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag86)[2 : length(colnames(flag_person_wide_flag86))]
flag_person_wide_flag86$flag86_r <- NA
for (i in temp){
  flag_person_wide_flag86$flag86_r <- paste(flag_person_wide_flag86$flag86_r, flag_person_wide_flag86[[i]], sep = " ")
}
flag_person_wide_flag86$flag86_r <- gsub("NA ", replacement="", flag_person_wide_flag86$flag86_r)
flag_person_wide_flag86$flag86_r <- gsub(" NA", replacement="", flag_person_wide_flag86$flag86_r)

#產生檢誤報告文字
flag86_temp <- flag_person_wide_flag86 %>%
  group_by(organization_id) %>%
  mutate(flag86_txt = paste("姓名：", flag86_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag86_txt)) %>%
  distinct(organization_id, flag86_txt)

#根據organization_id，展開成寬資料(wide)
flag86 <- flag86_temp %>%
  dcast(organization_id ~ flag86_txt, value.var = "flag86_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag86)[2 : length(colnames(flag86))]
flag86$flag86 <- NA
for (i in temp){
  flag86$flag86 <- paste(flag86$flag86, flag86[[i]], sep = "； ")
}
flag86$flag86 <- gsub("NA； ", replacement="", flag86$flag86)
flag86$flag86 <- gsub("； NA", replacement="", flag86$flag86)

#產生檢誤報告文字
flag86 <- flag86 %>%
  subset(select = c(organization_id, flag86)) %>%
  distinct(organization_id, flag86) %>%
  mutate(flag86 = if_else(substr(organization_id, 3, 3) == "1", paste0(flag86, "（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111學年度第二學期（112年2月1日-112年7月31日）退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）"), #私立
                                                                paste0(flag86, "（經比對貴校上一學年所填資料，上述人員並未出現於本學期的教員資料表或職員(工)資料表，請確認渠等是否於111年10月1日-112年7月31日退休或因故離職等，若於該學期退休或因故離職等，應於離退教職員(工)資料表填寫資料。如非於該學期退休或因故離職，或已介聘、調至他校，請來電告知。）"))) #公立


}else{
#偵測flag86是否存在。若不存在，則產生NA行
if('flag86' %in% ls()){
  print("flag86")
}else{
  flag86 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag86$flag86 <- ""
}
}
# flag91: 本學期離退教職員（工）資料表比對上一學年（期）教員/職員（工）資料表，同一身分識別碼所對應的姓名不同。 -------------------------------------------------------------------
flag_person <- drev_P_retire_merge_pre %>%
  rename(name = name.x, name_pre = name.y, name_retire = name, edu_name2 = edu_name2.x)

#本學期離退教職員（工）資料表比對上一學年（期）教員/職員（工）資料表，同一身分識別碼所對應的姓名不同。
flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$pre == 1 & is.na(flag_person$now) & flag_person$retire == 1 & flag_person$name_pre != flag_person$name_retire, 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name_pre, "/", flag_person$name_retire, sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
#根據organization_id，展開成寬資料(wide)
flag_person_wide_flag91 <- flag_person %>%
  subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, err_flag)) %>%
  subset(err_flag == 1) %>%
  dcast(organization_id ~ err_flag_txt, value.var = "err_flag_txt")

#合併所有name
temp <- colnames(flag_person_wide_flag91)[2 : length(colnames(flag_person_wide_flag91))]
flag_person_wide_flag91$flag91_r <- NA
for (i in temp){
  flag_person_wide_flag91$flag91_r <- paste(flag_person_wide_flag91$flag91_r, flag_person_wide_flag91[[i]], sep = " ")
}
flag_person_wide_flag91$flag91_r <- gsub("NA ", replacement="", flag_person_wide_flag91$flag91_r)
flag_person_wide_flag91$flag91_r <- gsub(" NA", replacement="", flag_person_wide_flag91$flag91_r)

#產生檢誤報告文字
flag91_temp <- flag_person_wide_flag91 %>%
  group_by(organization_id) %>%
  mutate(flag91_txt = paste("請確認：", flag91_r, sep = ""), "") %>%
  subset(select = c(organization_id, flag91_txt)) %>%
  distinct(organization_id, flag91_txt)

#根據organization_id，展開成寬資料(wide)
flag91 <- flag91_temp %>%
  dcast(organization_id ~ flag91_txt, value.var = "flag91_txt")

#合併教員資料表及職員(工)資料表報告文字
temp <- colnames(flag91)[2 : length(colnames(flag91))]
flag91$flag91 <- NA
for (i in temp){
  flag91$flag91 <- paste(flag91$flag91, flag91[[i]], sep = "； ")
}
flag91$flag91 <- gsub("NA； ", replacement="", flag91$flag91)
flag91$flag91 <- gsub("； NA", replacement="", flag91$flag91)

#產生檢誤報告文字
flag91 <- flag91 %>%
  subset(select = c(organization_id, flag91)) %>%
  distinct(organization_id, flag91) %>%
  mutate(flag91 = paste(flag91, "（離退人員於上一期資料填報姓名不相同。如已更名，請來電告知）", sep = ""))
}else{
#偵測flag91是否存在。若不存在，則產生NA行
if('flag91' %in% ls()){
  print("flag91")
}else{
  flag91 <- drev_person_1 %>%
    distinct(organization_id, .keep_all = TRUE) %>%
    subset(select = c(organization_id))
  flag91$flag91 <- ""
}
}

# flag95: 請確認專任教師名單是否完整。 (內參)-------------------------------------------------------------------
flag_person <- drev_person_1

#教育部統計處公布專任教師/兼任教師/職員人數
#跟統計處比較的分析，先內部參閱，暫不納入檢核，但我認為也許可以看不同波次學校填的人數比較，尤其是專任，應該不會差太多，若像跟統計處比較一樣差異太大，就是有問題

filename <- "./111_base0_revise.xlsx"

# 讀取檔案
moe_111_base0 <- read_excel(filename)

#統計處"專任教師"定義：以實際現有(編制內)人數計算，包括校長(大專附設除外)、超額分發教師、專任輔導教師、長期代理教師、特教班專任教師、原住民專任教師及教官，不含運動教練。服兵役及留職停薪教師，以占實缺之長期代理教師資料計列。
flag_person$count_emptype1 <- if_else(
  flag_person$sertype == "教師" & (flag_person$emptype == "專任" | flag_person$emptype == "代理" | flag_person$emptype == "代理(連)") | 
  flag_person$sertype == "校長" | 
  flag_person$sertype == "教官" | 
  flag_person$sertype == "主任教官"
    , 1, 0)

#統計處"兼任教師"定義：係指以部分時間擔任學校編制內教師依規定排課後尚餘之課務或特殊類科之課務者，已計列本表專任教師者除外。
flag_person$count_emptype2 <- if_else(flag_person$sertype == "教師" & flag_person$emptype == "兼任", 1, 0)

#統計處"職員"定義：依據「高級中等學校組織設置及員額編制標準」第8條，以實際現職(編制內)人數計算，包括辦理行政工作及一般技術工作之專任人員(含技士、技佐、營養師、護理師(或護士)、專任運動教練、救生員或運動傷害防護員、管理員及實習指導員等)。
flag_person$count_staff <- if_else(flag_person$source == "職員(工)資料表" & flag_person$emptype == "專任", 1, 0)

flag_person$count_emptype1 <- if_else(is.na(flag_person$count_emptype1), 0, flag_person$count_emptype1)
flag_person$count_emptype2 <- if_else(is.na(flag_person$count_emptype2), 0, flag_person$count_emptype2)

flag_person_wide_flag95 <- aggregate(cbind(count_emptype1, count_emptype2, count_staff) ~ organization_id, flag_person, sum) %>%
  left_join(moe_111_base0, by = "organization_id")

flag_person_wide_flag95$count_emptype1_1 <- as.numeric(flag_person_wide_flag95$count_emptype1_1)
flag_person_wide_flag95$count_emptype2_1 <- as.numeric(flag_person_wide_flag95$count_emptype2_1)
flag_person_wide_flag95$count_staff_1 <- as.numeric(flag_person_wide_flag95$count_staff_1)


flag_person_wide_flag95$flag_err <- 0
flag_person_wide_flag95$err_emptype1 <- (flag_person_wide_flag95$count_emptype1 - flag_person_wide_flag95$count_emptype1_1) / flag_person_wide_flag95$count_emptype1
flag_person_wide_flag95$err_emptype2 <- (flag_person_wide_flag95$count_emptype2 - flag_person_wide_flag95$count_emptype2_1) / flag_person_wide_flag95$count_emptype2
flag_person_wide_flag95$err_staff <- (flag_person_wide_flag95$count_staff - flag_person_wide_flag95$count_staff_1) / flag_person_wide_flag95$count_staff

flag_person_wide_flag95$err_emptype1 <- scales::percent(flag_person_wide_flag95$err_emptype1, accuracy = 0.1)
flag_person_wide_flag95$err_emptype2 <- scales::percent(flag_person_wide_flag95$err_emptype2, accuracy = 0.1)
flag_person_wide_flag95$err_staff <- scales::percent(flag_person_wide_flag95$err_staff, accuracy = 0.1)


flag_person_wide_flag95$err_flag_txt <- paste0("統計處專任教師人數：", 
                                               flag_person_wide_flag95$count_emptype1_1, 
                                               "人；", 
                                               "本資料庫專任教師、代理教師、校長、教官、主任教官人數：", 
                                               flag_person_wide_flag95$count_emptype1, 
                                               "；差異百分比", 
                                               flag_person_wide_flag95$err_emptype1)

#產生檢誤報告文字
flag95 <- flag_person_wide_flag95 %>%
  subset(select = c(organization_id, err_flag_txt)) %>%
  rename(flag95 = err_flag_txt) %>%
  distinct(organization_id, flag95)

# flag96: 校內一級主管（主任）原則由專任教職員擔（兼）任。 -------------------------------------------------------------------
flag_person <- drev_person_1

#職稱為"主任"且聘任類別不為專任(這學期都抓出來，再審酌是否請學校改)
flag_person$err_flag <- 0
flag_person$err_flag <- if_else((grepl("主任$", flag_person$admintitle0) | 
                                 grepl("主任$", flag_person$admintitle1) | 
                                 grepl("主任$", flag_person$admintitle2) | 
                                 grepl("主任$", flag_person$admintitle3)) 
                                & (flag_person$emptype != "專任") , 1, flag_person$err_flag)

#加註
flag_person$name <- if_else(grepl("主任$", flag_person$admintitle0) & flag_person$emptype != "專任", paste(flag_person$name, "（", flag_person$emptype, " ", flag_person$adminunit0, flag_person$admintitle0, "）", sep = ""), flag_person$name)
flag_person$name <- if_else(grepl("主任$", flag_person$admintitle1) & flag_person$emptype != "專任", paste(flag_person$name, "（", flag_person$emptype, " ", flag_person$adminunit1, flag_person$admintitle1, "）", sep = ""), flag_person$name)
flag_person$name <- if_else(grepl("主任$", flag_person$admintitle2) & flag_person$emptype != "專任", paste(flag_person$name, "（", flag_person$emptype, " ", flag_person$adminunit2, flag_person$admintitle2, "）", sep = ""), flag_person$name)
flag_person$name <- if_else(grepl("主任$", flag_person$admintitle3) & flag_person$emptype != "專任", paste(flag_person$name, "（", flag_person$emptype, " ", flag_person$adminunit3, flag_person$admintitle3, "）", sep = ""), flag_person$name)
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
  #根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag96 <- flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
    subset(err_flag == 1) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
  #合併所有name
  temp <- colnames(flag_person_wide_flag96)[3 : length(colnames(flag_person_wide_flag96))]
  flag_person_wide_flag96$flag96_r <- NA
  for (i in temp){
    flag_person_wide_flag96$flag96_r <- paste(flag_person_wide_flag96$flag96_r, flag_person_wide_flag96[[i]], sep = " ")
  }
  flag_person_wide_flag96$flag96_r <- gsub("NA ", replacement="", flag_person_wide_flag96$flag96_r)
  flag_person_wide_flag96$flag96_r <- gsub(" NA", replacement="", flag_person_wide_flag96$flag96_r)
  
  #產生檢誤報告文字
  flag96_temp <- flag_person_wide_flag96 %>%
    group_by(organization_id) %>%
    mutate(flag96_txt = paste(source, "：", flag96_r, sep = ""), "") %>%
    subset(select = c(organization_id, flag96_txt)) %>%
    distinct(organization_id, flag96_txt)
  
  #根據organization_id，展開成寬資料(wide)
  flag96 <- flag96_temp %>%
    dcast(organization_id ~ flag96_txt, value.var = "flag96_txt")
  
  #合併教員資料表及職員(工)資料表報告文字
  temp <- colnames(flag96)[2 : length(colnames(flag96))]
  flag96$flag96 <- NA
  for (i in temp){
    flag96$flag96 <- paste(flag96$flag96, flag96[[i]], sep = "； ")
  }
  flag96$flag96 <- gsub("NA； ", replacement="", flag96$flag96)
  flag96$flag96 <- gsub("； NA", replacement="", flag96$flag96)
  
  #產生檢誤報告文字
  flag96 <- flag96 %>%
    subset(select = c(organization_id, flag96)) %>%
    distinct(organization_id, flag96) %>%
    mutate(flag96 = paste(flag96, "（校內一級主管（主任）原則由專任教職員擔（兼）任，請協助再確認上述教職員是否擔（兼）任校內一級主管（主任），或協助再確認上述教職員之聘任類別）", sep = ""))
}else{
  #偵測flag96是否存在。若不存在，則產生NA行
  if('flag96' %in% ls()){
    print("flag96")
  }else{
    flag96 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
    flag96$flag96 <- ""
  }
}

# flag97: 專任和代理是否同時存在兩校以上。 -------------------------------------------------------------------
#這裡是撈所有學校的資料來比對
flag_person <- drev_person %>%
  select(c("organization_id", "edu_name2", "idnumber", "name", "sertype", "emptype", "emsub", "source")) %>%
  subset(emptype %in% c("專任", "代理", "代理(連)")) %>%
  group_by(idnumber) %>%
  mutate(index = n()) %>%
  filter(index > 1) %>%
  ungroup() %>%
  mutate(err_flag = 1)

flag_person$sertype <- if_else(is.na(flag_person$sertype), "職員(工)", flag_person$sertype)

#加註
flag_person$name <- paste(flag_person$name, "（", flag_person$emptype, flag_person$sertype, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
  #根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag97 <- flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
    subset(err_flag == 1) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
  #合併所有name
  temp <- colnames(flag_person_wide_flag97)[3 : length(colnames(flag_person_wide_flag97))]
  flag_person_wide_flag97$flag97_r <- NA
  for (i in temp){
    flag_person_wide_flag97$flag97_r <- paste(flag_person_wide_flag97$flag97_r, flag_person_wide_flag97[[i]], sep = " ")
  }
  flag_person_wide_flag97$flag97_r <- gsub("NA ", replacement="", flag_person_wide_flag97$flag97_r)
  flag_person_wide_flag97$flag97_r <- gsub(" NA", replacement="", flag_person_wide_flag97$flag97_r)
  
  #產生檢誤報告文字
  flag97_temp <- flag_person_wide_flag97 %>%
    group_by(organization_id) %>%
    mutate(flag97_txt = paste(source, "：請確認該員本學期是否在職：", flag97_r, sep = ""), "") %>%
    subset(select = c(organization_id, flag97_txt)) %>%
    distinct(organization_id, flag97_txt)
  
  #根據organization_id，展開成寬資料(wide)
  flag97 <- flag97_temp %>%
    dcast(organization_id ~ flag97_txt, value.var = "flag97_txt")
  
  #合併教員資料表及職員(工)資料表報告文字
  temp <- colnames(flag97)[2 : length(colnames(flag97))]
  flag97$flag97 <- NA
  for (i in temp){
    flag97$flag97 <- paste(flag97$flag97, flag97[[i]], sep = "； ")
  }
  flag97$flag97 <- gsub("NA； ", replacement="", flag97$flag97)
  flag97$flag97 <- gsub("； NA", replacement="", flag97$flag97)
  
  #產生檢誤報告文字
  flag97 <- flag97 %>%
    subset(select = c(organization_id, flag97)) %>%
    distinct(organization_id, flag97) %>%
    mutate(flag97 = paste(flag97, "", sep = ""))
}else{
  #偵測flag97是否存在。若不存在，則產生NA行
  if('flag97' %in% ls()){
    print("flag97")
  }else{
    flag97 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
    flag97$flag97 <- ""
  }
}

# flag98: 右欄所列人員身分識別碼與其他學校重複，且姓名、出生年月日、國籍別、最高學歷資訊與填列資料不同。 -------------------------------------------------------------------
#這裡是撈所有學校的資料來比對
flag_person <- drev_person %>%
  mutate(nation_recode = nation)

#最高學歷
flag_person$elv1 <- ""
flag_person$elv1 <- if_else(flag_person$ddegreen1 != "" & 
                              flag_person$ddegreen1 != "N", "博士", flag_person$elv1)
flag_person$elv1 <- if_else(flag_person$ddegreen1 == "N" & 
                              flag_person$ddegreen2 == "N" &
                              flag_person$mdegreen1 != "" & 
                              flag_person$mdegreen1 != "N", "碩士", flag_person$elv1)
flag_person$elv1 <- if_else(flag_person$ddegreen1 == "N" & 
                              flag_person$ddegreen2 == "N" &
                              flag_person$mdegreen1 == "N" & 
                              flag_person$mdegreen2 == "N" &
                              flag_person$bdegreen1 != "" & 
                              flag_person$bdegreen1 != "N", "學士", flag_person$elv1)
flag_person$elv1 <- if_else(flag_person$ddegreen1 == "N" & 
                              flag_person$ddegreen2 == "N" &
                              flag_person$mdegreen1 == "N" & 
                              flag_person$mdegreen2 == "N" &
                              flag_person$bdegreen1 == "N" & 
                              flag_person$bdegreen2 == "N" & 
                              flag_person$adegreen1 != "" & 
                              flag_person$adegreen1 != "N", "副學士", flag_person$elv1)
flag_person$elv1 <- if_else(flag_person$degree == "N", "高中職以下", flag_person$elv1)


#刪除"籍" "藉"
flag_person$nation_recode <- gsub("籍", replacement="", flag_person$nation_recode)
flag_person$nation_recode <- gsub("藉", replacement="", flag_person$nation_recode)

#名詞統一
flag_person <- flag_person %>%   
  mutate(nation_recode = recode(nation_recode, 
                                "TWN" = "本國", 
                                "中華民國" = "本國", 
                                "台灣" = "本國", 
                                "臺灣" = "本國", 
                                "大韓民國" = "韓國", 
                                "SocialistRepublicofVietnam" = "越南", 
                                "中國大陸" = "中國"))

#姓名檢查
flag_person_name <- flag_person %>%
  select(c("organization_id", "edu_name2", "idnumber", "name", "source")) %>%
  group_by(idnumber) %>%
  filter(n_distinct(name) > 1) %>%
  ungroup() %>%
  mutate(err_flag_name = 1) %>%
  select("organization_id", "idnumber", "err_flag_name")

#出生年月日檢查
flag_person_birthdate <- flag_person %>%
  select(c("organization_id", "edu_name2", "idnumber", "name", "birthdate", "source")) %>%
  group_by(idnumber) %>%
  filter(n_distinct(birthdate) > 1) %>%
  ungroup() %>%
  mutate(err_flag_birthdate = 1) %>%
  select("organization_id", "idnumber", "err_flag_birthdate")

#國籍別檢查
flag_person_nation <- flag_person %>%
  select(c("organization_id", "edu_name2", "idnumber", "name", "nation", "nation_recode", "source")) %>%
  group_by(idnumber) %>%
  filter(n_distinct(nation_recode) > 1) %>%
  ungroup() %>%
  mutate(err_flag_nation = 1)

#"國籍別"不合理的情況在flag8處理
flag_person_nation <- flag_person_nation %>%
  left_join(flag_person_flag8, by = c( "idnumber")) %>%
  subset(err_flag_nation == 1 & is.na(err_flag)) %>%
  select("organization_id", "idnumber", "err_flag_nation")

#最高學位檢查
flag_person_elv1 <- flag_person %>%
  select(c("organization_id", "edu_name2", "idnumber", "name", "emptype", "sertype", "elv1", "ddegreen1", "ddegreeu1", "ddegreeg1", "ddegreen2", "ddegreeu2", "ddegreeg2", "mdegreen1", "mdegreeu1", "mdegreeg1", "mdegreen2", "mdegreeu2", "mdegreeg2", "bdegreen1", "bdegreeu1", "bdegreeg1", "bdegreen2", "bdegreeu2", "bdegreeg2", "adegreen1", "adegreeu1", "adegreeg1", "adegreen2", "adegreeu2", "adegreeg2", "source")) %>%
  group_by(idnumber) %>%
  filter(n_distinct(elv1) > 1) %>%
  ungroup() %>%
  mutate(err_flag_elv1 = 1) %>%
  select("organization_id", "idnumber", "err_flag_elv1")

#合併檢查結果
flag_person <- flag_person %>%
  left_join(flag_person_name, by = c("organization_id", "idnumber")) %>%
  left_join(flag_person_birthdate, by = c("organization_id", "idnumber")) %>%
  left_join(flag_person_nation, by = c("organization_id", "idnumber")) %>%
  left_join(flag_person_elv1, by = c("organization_id", "idnumber")) 

flag_person$err_flag_name[is.na(flag_person$err_flag_name)] <- 0
flag_person$err_flag_birthdate[is.na(flag_person$err_flag_birthdate)] <- 0
flag_person$err_flag_nation[is.na(flag_person$err_flag_nation)] <- 0
flag_person$err_flag_elv1[is.na(flag_person$err_flag_elv1)] <- 0

flag_person$err_flag98 <- flag_person$err_flag_name + flag_person$err_flag_birthdate + flag_person$err_flag_nation + flag_person$err_flag_elv1

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$err_flag98 != 0, 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（", sep = "")
flag_person$name <- if_else(flag_person$err_flag_name != 0, paste(flag_person$name, "姓名", "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_flag_birthdate != 0, paste(flag_person$name, "出生年月日：", flag_person$birthdate, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_flag_nation != 0, paste(flag_person$name, "國籍別：", flag_person$nation, "；", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_flag_elv1 != 0, paste(flag_person$name, "最高學歷：", flag_person$elv1, sep = ""), flag_person$name)
flag_person$name <- paste(flag_person$name, "）", sep = "")
flag_person$name <- gsub("；）", replacement = "）", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
  #根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag98 <- flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
    subset(err_flag == 1) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
  #合併所有name
  temp <- colnames(flag_person_wide_flag98)[3 : length(colnames(flag_person_wide_flag98))]
  flag_person_wide_flag98$flag98_r <- NA
  for (i in temp){
    flag_person_wide_flag98$flag98_r <- paste(flag_person_wide_flag98$flag98_r, flag_person_wide_flag98[[i]], sep = " ")
  }
  flag_person_wide_flag98$flag98_r <- gsub("NA ", replacement="", flag_person_wide_flag98$flag98_r)
  flag_person_wide_flag98$flag98_r <- gsub(" NA", replacement="", flag_person_wide_flag98$flag98_r)
  
  #產生檢誤報告文字
  flag98_temp <- flag_person_wide_flag98 %>%
    group_by(organization_id) %>%
    mutate(flag98_txt = paste(source, "：請確認該員基本資料：", flag98_r, sep = ""), "") %>%
    subset(select = c(organization_id, flag98_txt)) %>%
    distinct(organization_id, flag98_txt)
  
  #根據organization_id，展開成寬資料(wide)
  flag98 <- flag98_temp %>%
    dcast(organization_id ~ flag98_txt, value.var = "flag98_txt")
  
  #合併教員資料表及職員(工)資料表報告文字
  temp <- colnames(flag98)[2 : length(colnames(flag98))]
  flag98$flag98 <- NA
  for (i in temp){
    flag98$flag98 <- paste(flag98$flag98, flag98[[i]], sep = "； ")
  }
  flag98$flag98 <- gsub("NA； ", replacement="", flag98$flag98)
  flag98$flag98 <- gsub("； NA", replacement="", flag98$flag98)
  
  #產生檢誤報告文字
  flag98 <- flag98 %>%
    subset(select = c(organization_id, flag98)) %>%
    distinct(organization_id, flag98) %>%
    mutate(flag98 = paste(flag98, "", sep = ""))
}else{
  #偵測flag98是否存在。若不存在，則產生NA行
  if('flag98' %in% ls()){
    print("flag98")
  }else{
    flag98 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
    flag98$flag98 <- ""
  }
}

# flag99: 教員聘任類別、技術教師、專任輔導教師與業界專家（業師）之檢查-------------------------------------------------------------------
  #1.	技術教師之聘任類別不應為「兼任」或「鐘點教師」。
  #2.	專任輔導教師之聘任類別不應為「兼任」或「鐘點教師」。
  #3.	業界專家（業師）之聘任類別不應為「專任」或「代理」

flag_person <- drev_person_1

  #技術教師不可為兼任或鐘點教師
flag_person$err_flag1 <- 0
flag_person$err_flag1 <- if_else(flag_person$skillteacher == "Y" & flag_person$emptype %in% c("兼任", "鐘點教師") & flag_person$source == "教員資料表", 1, flag_person$err_flag1)

  #專輔教師不可為兼任或鐘點教師
flag_person$err_flag2 <- 0
flag_person$err_flag2 <- if_else(flag_person$counselor == "Y" & flag_person$emptype %in% c("兼任", "鐘點教師") & flag_person$source == "教員資料表", 1, flag_person$err_flag2)

#業師不可為專任或代理
flag_person$err_flag3 <- 0
flag_person$err_flag3 <- if_else(flag_person$expecter == "Y" & flag_person$emptype %in% c("專任", "代理", "代理(連)") & flag_person$source == "教員資料表", 1, flag_person$err_flag3)

flag_person$err_flag_99 <- flag_person$err_flag1 + flag_person$err_flag2 + flag_person$err_flag3

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$err_flag_99 != 0, 1, flag_person$err_flag)

#加註
flag_person$name <- paste(flag_person$name, "（", " ", sep = "")
flag_person$name <- if_else(flag_person$err_flag1 != 0, paste(flag_person$name, "技術教師 ", "、", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_flag2 != 0, paste(flag_person$name, "專任輔導教師 ", "、", sep = ""), flag_person$name)
flag_person$name <- if_else(flag_person$err_flag3 != 0, paste(flag_person$name, "業界專家", sep = ""), flag_person$name)
flag_person$name <- paste(flag_person$name, "（", flag_person$emptype, "））", sep = "")
flag_person$name <- gsub("、）", replacement = "）", flag_person$name)
flag_person$name <- gsub("技術教師 、（", replacement = "技術教師（", flag_person$name)
flag_person$name <- gsub("專任輔導教師 、（", replacement = "專任輔導教師（", flag_person$name)
flag_person$name <- gsub("業界專家 、（", replacement = "業界專家（", flag_person$name)
flag_person$name <- gsub("（）", replacement = "", flag_person$name)

#呈現姓名
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ flag_person$name,
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
  #根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag99 <- flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
    subset(err_flag == 1) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
  #合併所有name
  temp <- colnames(flag_person_wide_flag99)[3 : length(colnames(flag_person_wide_flag99))]
  flag_person_wide_flag99$flag99_r <- NA
  for (i in temp){
    flag_person_wide_flag99$flag99_r <- paste(flag_person_wide_flag99$flag99_r, flag_person_wide_flag99[[i]], sep = " ")
  }
  flag_person_wide_flag99$flag99_r <- gsub("NA ", replacement="", flag_person_wide_flag99$flag99_r)
  flag_person_wide_flag99$flag99_r <- gsub(" NA", replacement="", flag_person_wide_flag99$flag99_r)
  
  #產生檢誤報告文字
  flag99_temp <- flag_person_wide_flag99 %>%
    group_by(organization_id) %>%
    mutate(flag99_txt = paste(source, "姓名：", flag99_r, sep = ""), "") %>%
    subset(select = c(organization_id, flag99_txt)) %>%
    distinct(organization_id, flag99_txt)
  
  #根據organization_id，展開成寬資料(wide)
  flag99 <- flag99_temp %>%
    dcast(organization_id ~ flag99_txt, value.var = "flag99_txt")
  
  #合併教員資料表及職員(工)資料表報告文字
  temp <- colnames(flag99)[2 : length(colnames(flag99))]
  flag99$flag99 <- NA
  for (i in temp){
    flag99$flag99 <- paste(flag99$flag99, flag99[[i]], sep = "； ")
  }
  flag99$flag99 <- gsub("NA； ", replacement="", flag99$flag99)
  flag99$flag99 <- gsub("； NA", replacement="", flag99$flag99)
  
  #產生檢誤報告文字
  flag99 <- flag99 %>%
    subset(select = c(organization_id, flag99)) %>%
    distinct(organization_id, flag99) %>%
    mutate(flag99 = paste(flag99, "（請確認上開人員之『聘任類別』，或是否具備相關身分資格。）", sep = ""))
}else{
  #偵測flag99是否存在。若不存在，則產生NA行
  if('flag99' %in% ls()){
    print("flag99")
  }else{
    flag99 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
    flag99$flag99 <- ""
  }
}

# flag100: 校長「本校到職前學校服務總年資」偏小。 -------------------------------------------------------------------
flag_person <- drev_person_1 %>%
  subset(source == "教員資料表")

#本校到職前學校服務總年資
flag_person$beoby <- substr(flag_person$beobdym, 1, 2) %>% as.numeric
flag_person$beobm <- substr(flag_person$beobdym, 3, 4) %>% as.numeric

flag_person$beob <- (flag_person$beoby + (flag_person$beobm / 12))

flag_person$err_flag <- 0
flag_person$err_flag <- if_else(flag_person$sertype == "校長" & flag_person$beob < 10, 1, flag_person$err_flag)

#加註
flag_person$err_flag_txt <- ""
flag_person$err_flag_txt <- case_when(
  flag_person$err_flag == 1 ~ paste(flag_person$name, "（本校到職前學校服務總年資：", flag_person$beobdym, "）", sep = ""),
  TRUE ~ flag_person$err_flag_txt
)

if (dim(flag_person %>% subset(err_flag == 1))[1] != 0){
  #根據organization_id + source，展開成寬資料(wide)
  flag_person_wide_flag100 <- flag_person %>%
    subset(select = c(organization_id, idnumber, err_flag_txt, edu_name2, source, err_flag)) %>%
    subset(err_flag == 1) %>%
    dcast(organization_id + source ~ err_flag_txt, value.var = "err_flag_txt")
  
  #合併所有name
  temp <- colnames(flag_person_wide_flag100)[3 : length(colnames(flag_person_wide_flag100))]
  flag_person_wide_flag100$flag100_r <- NA
  for (i in temp){
    flag_person_wide_flag100$flag100_r <- paste(flag_person_wide_flag100$flag100_r, flag_person_wide_flag100[[i]], sep = " ")
  }
  flag_person_wide_flag100$flag100_r <- gsub("NA ", replacement="", flag_person_wide_flag100$flag100_r)
  flag_person_wide_flag100$flag100_r <- gsub(" NA", replacement="", flag_person_wide_flag100$flag100_r)
  
  #產生檢誤報告文字
  flag100_temp <- flag_person_wide_flag100 %>%
    group_by(organization_id) %>%
    mutate(flag100_txt = paste(flag100_r, sep = ""), "") %>%
    subset(select = c(organization_id, flag100_txt)) %>%
    distinct(organization_id, flag100_txt)
  
  #根據organization_id，展開成寬資料(wide)
  flag100 <- flag100_temp %>%
    dcast(organization_id ~ flag100_txt, value.var = "flag100_txt")
  
  #合併教員資料表及職員(工)資料表報告文字
  temp <- colnames(flag100)[2 : length(colnames(flag100))]
  flag100$flag100 <- NA
  for (i in temp){
    flag100$flag100 <- paste(flag100$flag100, flag100[[i]], sep = "； ")
  }
  flag100$flag100 <- gsub("NA； ", replacement="", flag100$flag100)
  flag100$flag100 <- gsub("； NA", replacement="", flag100$flag100)
  
  #產生檢誤報告文字
  flag100 <- flag100 %>%
    subset(select = c(organization_id, flag100)) %>%
    distinct(organization_id, flag100) %>%
    mutate(flag100 = paste(flag100, "（校長「本校到職前學校服務總年資」偏小，請確認校長之「本校到職日期」、「本校到職前學校服務總年資」。）", sep = ""))
}else{
  #偵測flag100是否存在。若不存在，則產生NA行
  if('flag100' %in% ls()){
    print("flag100")
  }else{
    flag100 <- drev_person_1 %>%
      distinct(organization_id, .keep_all = TRUE) %>%
      subset(select = c(organization_id))
    flag100$flag100 <- ""
  }
}

# 建立合併列印檔 -------------------------------------------------------------------
temp <- c("flag2", "flag3", "flag6", "flag7", "flag8", "flag9", "flag15", "flag16", "flag18", "flag19", "flag20", "flag24", "flag39", "flag45", "flag47", "flag48", "flag49", "flag50", "flag51", "flag52", "flag57", "flag59", "flag62", "flag64", "flag80", "flag82", "flag83", "flag84", "flag85", "flag86", "flag89", "flag90", "flag91", "flag92", "flag93", "flag94", "flag95", "flag96", "flag97", "flag98", "flag99", "flag100", "sp3", "sp5", "sp6")
check02 <- merge(x = edu_name2, y = flag1, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag2, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag3, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag6, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag7, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag8, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag9, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag15, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag16, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag18, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag19, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag20, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag24, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag39, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag45, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag47, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag48, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag49, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag50, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag51, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag52, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag57, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag59, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag62, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag64, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag80, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag82, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag83, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag84, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag85, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag86, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag89, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag90, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag91, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag92, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag93, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag94, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag95, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag96, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag97, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag98, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag99, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = flag100, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = spe3, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = spe5, by = c("organization_id"), all.x = TRUE, all.y = TRUE)
check02 <- merge(x = check02, y = spe6, by = c("organization_id"), all.x = TRUE, all.y = TRUE)

#輸出檢核結果excel檔
openxlsx :: write.xlsx(check02, file = "./dist/edhr-112t1-check_print-人事.xlsx", rowNames = FALSE, overwrite = TRUE)

} #本次無新資料的判斷


} #離退教職員(工)資料表尚未建立的判斷

} #職員(工)資料表尚未建立的判斷

} #教員資料表尚未建立的判斷
