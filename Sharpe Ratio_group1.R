# 7.0 ��װ�����������
install.packages("tidyverse")
install.packages("lubridate")
install.packages("readxl")
install.packages("highcharter")
install.packages("tidyquant")
install.packages("timetk")
install.packages("tibbletime")
install.packages("quantmod")
install.packages("PerformanceAnalytics")
install.packages("scales")
install.packages('data.table')
install.packages('dplyr')
install.packages('DBI')
install.packages('RMySQL')
install.packages('plyr')
install.packages('xts')

library(dplyr)
library(plyr)
library(tidyverse)
library(lubridate)
library(xts)
library(readxl)
library(highcharter)
library(quantmod)
library(tidyquant)
library(timetk)
library(tibbletime)
library(PerformanceAnalytics)
library(scales)
library(data.table)
library(DBI)
library(RMySQL)

# �����ݿ���������
# ���� ��ָ����Ϊ�о���Ͷ����ϣ�ѡȡ��ָ֤�����ۺ�ָ���ʹ�ҵ��ָ��2013.01.01-2019.09.30�����̼�������
mydb= dbConnect(MySQL(),user='ktruc002', password='35442fed', dbname='cn_stock_quote', host='172.19.3.250')

## ��ȡ��ָ֤��������Indextable1
SQL_statement<- "SELECT  `trade_date`,  `index_code`, `last` 
                  FROM `cn_stock_index`.`daily_quote`
                  WHERE index_code='000001' and trade_date>'2013-01-01 00:00:00'
                  ORDER BY `trade_date` DESC, `index_name` DESC "
Indextable1 <- dbGetQuery(mydb,SQL_statement)

## ��ȡ�ۺ�ָ��������Indextable2
SQL_statement<- "SELECT  `trade_date`,  `index_code`,  `last`
                  FROM `cn_stock_index`.`daily_quote`
                  WHERE index_code='000008'and trade_date>'2013-01-01 00:00:00'
                  ORDER BY `trade_date` DESC, `index_name` DESC "
Indextable2 <- dbGetQuery(mydb,SQL_statement)

## ��ȡ��ҵ��ָ��������Indextable3
SQL_statement<- "SELECT  `trade_date`,  `index_code`,  `last`
                  FROM `cn_stock_index`.`daily_quote`
                  WHERE index_code='399635'and trade_date>'2013-01-01 00:00:00'
                  ORDER BY `trade_date` DESC, `index_name` DESC "
Indextable3 <- dbGetQuery(mydb,SQL_statement)

## �����ű������ڽ��е�ֵ���ӣ��������ֶν��д���������ʱ������
IndexTable<-inner_join(inner_join(Indextable1,Indextable2,by="trade_date"),Indextable3,by="trade_date")
data <- as.data.table(IndexTable)
date <- as.Date(data$trade)
data[,':='(date=date)]
table <- data[,!1]
setcolorder(table,c('date','index_code.x','last.x','index_code.y','last.y' ,'index_code','last'))

## �ͷţ�ɾ�������ñ���
rm(data,Indextable1,Indextable2,Indextable3,date)

## �õ�ԭʼ���ݱ� xts_table,�����б������޸�Ϊ��ָ�����_ָ�����롱
xts_table <- as.xts.data.table(table) %>%
  rename(c(last.x='SZZS_000001',last.y='ZHZS_000008',last='CYBZ_399635'))
head(xts_table,5)
### save(xts_table,file="D://xtsdata.Rdata") #����Rdata��������
### load("D://xtsdata.Rdata")  #�Ա��ر����rdata��ȡ����


## ��ز�������
prices <- xts_table #ָ���۸�����
rfr<-0.03 #�޷���������
symbols <- c("SZZS_000001","ZHZS_000008", "CYBZ_399635")#�����־���������۸�����������ʾ��������

# 7.1-7.4 ���ձ���
# 7.1 xts��
## �������̼۵õ���������
## indexAtѡ���³�(firstog),��ĩ(lastof)
prices_monthly <- to.monthly(prices,
                             indexAt="lastof",
                             OHLC=FALSE)

## ����������,����������(log)��������������ʣ�discrete)
asset_returns_xts <- Return.calculate(prices_monthly,method="log") %>% 
  na.omit()
head(asset_returns_xts,3)

## �������ձ���
sharpe_xts <-SharpeRatio(asset_returns_xts,
                         Rf = rfr,
                         FUN = "StdDev") %>%
  `colnames<-`(c("SZZS_000001","ZHZS_000008","CYBZ_399635"))
sharpe_xts <-data.table(sharpe_xts) %>%
  gather(asset, sharpe_xts)
sharpe_xts

#7.2 tidyverse��
## ������������
asset_returns_dplyr_byhand<-
  prices %>%
  to.monthly(indexAt="lastof", OHLC =FALSE) %>%
  # �����ݿ�����ת��Ϊdate��������
  data.frame(date= index(.)) %>%
  # �Ƴ���������
  remove_rownames() %>%
  gather(asset, prices, -date) %>%
  group_by(asset) %>%
  # �������������
  mutate(returns =(log(prices)-log(lag(prices)))) %>%  
  select(-prices) %>%
  spread(asset, returns) %>%
  select(date, symbols) %>%
   #ȥ����ֵ
  na.omit()
head(asset_returns_dplyr_byhand,3)

## �������ձ��� 
sharpe_tidyverse<-
  asset_returns_dplyr_byhand %>%
  summarise(SZZS_000001 = mean(SZZS_000001 - rfr)/
              sd(SZZS_000001 - rfr),ZHZS_000008 = mean(ZHZS_000008 - rfr)/
              sd(ZHZS_000008- rfr),CYBZ_399635 = mean(CYBZ_399635- rfr)/
              sd(CYBZ_399635- rfr)) %>%
  gather(asset, sharpe_tidyverse)
sharpe_tidyverse

#7.3 tidyquant��
## ������������
asset_returns_tq_monthly<-
  prices %>%
  tk_tbl(preserve_index=TRUE,
         rename_index="date") %>%
  gather(asset, prices, -date) %>%
  group_by(asset) %>%
  tq_transmute(mutate_fun=periodReturn,
               period ="monthly",
               type ="log") %>%
  # �޳����ڷǹ��е�����
  spread(asset, monthly.returns) %>%
  select(date, symbols) %>%
  slice(-1) %>% 
  # �������ݸ�ʽ
  gather(asset, returns, -date) %>%
  group_by(asset)
head(asset_returns_tq_monthly,3)

## ��������ָ�������ձ���
sharpe_tq<-asset_returns_tq_monthly %>%
  tq_performance( Ra=returns,
                  performance_fun = SharpeRatio,
                  Rf = rfr,
                  FUN = "StdDev")
colnames(sharpe_tq) <- c("asset","sharpe_tq")
sharpe_tq

## �Ƚ����ַ��������ͬһָ�����ձ���
IndexCompare<-inner_join(inner_join(sharpe_tq,
                                    sharpe_tidyverse,
                                    by="asset"),
                         sharpe_xts,
                         by="asset")
IndexCompare

## ����ͬʱ��(2013.01.01-2019.09.30)S&P500�����ձ���
### ��yahoo��ȡS&P500����������
SPY_returns_xts <-getSymbols("SPY",
                                src = 'yahoo',
                                from = "2013-01-01",
                                to = "2019-09-30",
                                auto.assign = TRUE,
                                warnings = FALSE) %>%
  map(~Ad(get(.))) %>%
  reduce(merge) %>%
  `colnames<-`("SPY") %>%
  to.monthly(indexAt = "lastof",
             OHLC = FALSE)

### �������ձ���
sharpe_SPY <- SPY_returns_xts %>%
  tk_tbl(preserve_index = TRUE,
         rename_index = "date") %>%
  mutate(returns =
           (log(SPY) - log(lag(SPY)))) %>%
  na.omit() %>%
  summarise(ratio =
              mean(returns - rfr)/sd(returns - rfr))

sharpe_SPY

#7.4 ���ձ��ʿ��ӻ�
## 7.4.1 ������ָ֤�������������� �������ʴ����޷���������С���޷������ʵ����ݣ��ֱ����
sharpe_byhand_with_return_columns <-
  asset_returns_dplyr_byhand %>%
  mutate(ratio =
           mean(SZZS_000001 - rfr)/sd(SZZS_000001 - rfr)) %>%
  mutate(returns_below_rfr =
           if_else(SZZS_000001 < rfr, SZZS_000001, as.numeric(NA))) %>%
  mutate(returns_above_rfr =
           if_else(SZZS_000001 > rfr,SZZS_000001, as.numeric(NA))) %>%
  mutate_if(is.numeric, funs(round(.,4)))
sharpe_byhand_with_return_columns %>%
  head(5)

## 7.4.2 ����ɢ��ͼ���˽�����޷�������������޷������ʵ���ָ֤����������
##      ����ɫ���ߴ������޷������ʣ�����������Ϊ2016-06-30�Ĵ�ֱ�ߣ�
sharpe_byhand_with_return_columns %>%
  ggplot(aes(x = date)) +
  geom_point(aes(y = returns_below_rfr),
             colour = "red") +
  geom_point(aes(y = returns_above_rfr),
             colour = "green") +
  geom_vline(xintercept =
               as.numeric(as.Date("2016-06-30")),
             color = "blue") +
  geom_hline(yintercept = rfr,
             color = "purple",
             linetype = "dotted") +
  annotate(geom = "text",
           x = as.Date("2016-06-30"),
           y = -.04,
           label = "Election",
           fontface = "plain",
           angle = 90,
           alpha = .5,
           vjust = 1.5) +
  ylab("percent monthly returns") +
  scale_y_continuous(breaks = pretty_breaks(n = 10)) +
  scale_x_date(breaks = pretty_breaks( n = 8))

## 7.4.3 ��ָ֤����������ƫ���޷��������ʵ�ֱ��ͼ�����ߴ������޷��������ʣ�
sharpe_byhand_with_return_columns %>%
  ggplot(aes(x = SZZS_000001)) +
  geom_histogram(alpha = 0.45,
                 binwidth = .01,
                 fill = "cornflowerblue") +
  geom_vline(xintercept = rfr,
             color = "green") +
  annotate(geom = "text",
           x = rfr,
           y = 13,
           label = "rfr",
           fontface = "plain",
           angle = 90,
           alpha = .5,
           vjust = 1)

## 7.4.4 ��׼��-���ձ���ͼ��- �Ƚ�����ָ����S&P500ָ���ı�׼�������ձ���
## ʹ��ggplot��

### ����SPY�ı�׼��
SPY_sd_xts <- 
  SPY_returns_xts %>% 
  Return.calculate(method="log") %>% 
  na.omit() %>%
  StdDev()

detach("package:plyr", unload = TRUE) #��sharpe_tq<-asset_returns_tq_monthly���з������ݷ���ʱ�ɹ�������Ҫ��ж��plyr��
### ����SPY���ݵ㲢��ͼ
asset_returns_tq_monthly %>%
  group_by(asset) %>%
  summarise(stand_dev = sd(returns),
            sharpe = mean(returns - rfr)/
              sd(returns - rfr))%>%
  add_row(asset = "SPY",
          stand_dev =
            SPY_sd_xts[1],
          sharpe =
            sharpe_SPY$ratio) %>%
  ggplot(aes(x = stand_dev,
             y = sharpe,
             color = asset)) +
  geom_point(size = 2) +
  ylab("Sharpe Ratio") +
  xlab("standard deviation") +
  ggtitle("Sharpe Ratio versus Standard Deviation") +
  theme_update(plot.title = element_text(hjust = 0.5)) +
  scale_x_continuous(limits = c(0,0.12)) +
  scale_y_continuous(limits = c(-0.7,-0.15))


# 7.5-7.8 �������ձ���
library(plyr)
# 7.5 xts��
## ���ù�������Ĵ���Ϊ12����
window <- 12

## ����������ձ���
rolling_sharpe_xts <-
  rollapply(asset_returns_xts, #��7.1��ʹ��xts������õ��ĸ�ָ������������
            window,
            function(x)
              SharpeRatio(x,
                          Rf = rfr,
                          FUN = "StdDev")) %>%
  na.omit() %>%
  `colnames<-`(c("rol_sharpe_000001_xts","rol_sharpe_000008_xts", "rol_sharpe_399635_xts"))
head(rolling_sharpe_xts,5)

# 7.6 tidyverse��tibbletime��
## ����������ձ��ʼ��㺯��
sharpe_roll_12 <-
  rollify(function(returns) {
    ratio = mean(returns - rfr)/sd(returns - rfr)
  },
  window = window)

## ����������ձ���
rolling_sharpe_tidy_tibbletime <-
  asset_returns_dplyr_byhand %>%  #��7.2��ʹ��tidyverse������õ��ĸ�ָ������������
  as_tbl_time(index = date) %>%
  mutate(rol_sharpe_000001_tbltime = sharpe_roll_12(SZZS_000001),
         rol_sharpe_000008_tbltime = sharpe_roll_12(ZHZS_000008),
         rol_sharpe_399635_tbltime = sharpe_roll_12(CYBZ_399635)) %>%
  na.omit() %>%
  select(-SZZS_000001,-ZHZS_000008,-CYBZ_399635)
head(rolling_sharpe_tidy_tibbletime,5)

#7.7 tidyquant��
## �������ձ��ʼ��㺯��
sharpe_tq_roll <- function(df){
  SharpeRatio(df,
              Rf = rfr,
              FUN = "StdDev")
}

## ����������ձ���
rolling_sharpe_tq <-
  asset_returns_tq_monthly %>%  #��7.3��ʹ��tidyquant������õ��ĸ�ָ������������
  spread(asset, returns) %>%   #������ʽ
  tq_mutate(
    select = symbols,
    mutate_fun = rollapply,
    width = window,
    align = "right",
    FUN = sharpe_tq_roll,
    col_rename = c("rol_sharpe_000001_tq","rol_sharpe_000008_tq", "rol_sharpe_399635_tq")
  ) %>%
  na.omit()
head(rolling_sharpe_tq,5)

## �Ա��������õ��ļ�����
## �ֱ�Ƚϸ�ָ��������������
rolling_sharpe_xts1 <- rolling_sharpe_xts %>% data.frame(date = index(.))
for(i in c("000001","000008","399635")) { 
  rolling_sharpe_temp <- 
    merge(rolling_sharpe_tidy_tibbletime[c("date",paste("rol_sharpe_", i,"_tbltime", sep = ""))],
          rolling_sharpe_tq[c("date",paste("rol_sharpe_", i,"_tq", sep = ""))],by="date")
  a <- paste("rolling_sharpe_", i,sep = "")
  assign(a, 
         merge(rolling_sharpe_temp,rolling_sharpe_xts1[c("date",paste("rol_sharpe_", i,"_xts", sep = ""))],
               by="date"))
}
head(rolling_sharpe_000001)
head(rolling_sharpe_000008)
head(rolling_sharpe_399635)

# 7.8 �������ձ��ʿ��ӻ�
## highcharter��xts��
## ���Ƹ�ָ�����ձ�����2014.01-2019.09�ı仯����
highchart(type = "stock") %>%
  hc_title(text = "Rolling 12-Month Sharpe") %>%
  hc_add_series(rolling_sharpe_xts$rol_sharpe_000001_xts,
                name = "sharpe_000001",
                color = "blue") %>%
  hc_add_series(rolling_sharpe_xts$rol_sharpe_000008_xts,
                name = "sharpe_000008",
                color = "red") %>%
  hc_add_series(rolling_sharpe_xts$rol_sharpe_399635_xts,
                name = "sharpe_399635",
                color = "black") %>%
  hc_navigator(enabled = FALSE) %>%
  hc_scrollbar(enabled = FALSE) %>%
  hc_add_theme(hc_theme_flat()) %>%
  hc_exporting(enabled = TRUE)

## ggplot��
### ���Ƶ�ָ���Ĺ������ձ��ʱ仯ͼ
rolling_sharpe_xts$rol_sharpe_000001_xts %>%
  tk_tbl(preserve_index = TRUE,
         rename_index = "date") %>%
  ggplot(aes(x = date,
             y = rol_sharpe_000001_xts)) +
  geom_line(color = "cornflowerblue") +
  ggtitle("Rolling 12-Month Sharpe Ratio") +
  labs(y = "rolling sharpe ratio") +
  scale_x_date(breaks = pretty_breaks(n = 8)) +
  theme(plot.title = element_text(hjust = 0.5))

### ���ƶ�ָ���Ĺ������ձ��ʱ仯ͼ
rolling_sharpe_xts_long <-
  rolling_sharpe_xts %>%
  data.frame(date = index(.)) %>%
  gather(asset, sharpe, -date) %>%
  group_by(asset)
rolling_sharpe_xts_long %>%
  ggplot(aes(x = date, y=sharpe,color= asset)) +
  geom_line() +
  ggtitle("Rolling 12-Month Sharpe Ratio") +
  labs(y = "rolling sharpe ratio") +
  scale_x_date(breaks = pretty_breaks(n = 8)) +
  theme(plot.title = element_text(hjust = 0.5))