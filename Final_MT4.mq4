// Use sqlite library to store trade records, so need to import first
// The library is downloaded from website
//#include <sqlite.mqh>

//+------------------------------------------------------------------+
//| Input variables
//+------------------------------------------------------------------+
input int intervalSecs = 360; // 6 mins interval for normal execution
input int twap_interval = 60; // 1 mins interval for TWAP close
input bool isLong = true; // Long or Short

//+------------------------------------------------------------------+
//| Define the order size for each execution time window
//+------------------------------------------------------------------+
double orderSize1 = 20000.0;
double orderSize2 = 30000.0;
double orderSize3 = 20000.0;
double orderSize4 = 30000.0;
double orderSize5 = 0.0;
double orderSize6 = 0.0;

//+------------------------------------------------------------------+
//| Stores the total executed size
//+------------------------------------------------------------------+
double executed1 = 0.0;
double executed2 = 0.0;
double executed3 = 0.0;
double executed4 = 0.0;

//+------------------------------------------------------------------+
//| These variables indicates whether each execution time windows is finished
//+------------------------------------------------------------------+
bool finished1 = false;
bool finished2 = false;
bool finished3 = false;
bool finished4 = false;
bool finished5 = false;
bool finished6 = false;

//+------------------------------------------------------------------+
//| These variables stores the executed * order_price, in order to calculate the average price
//+------------------------------------------------------------------+
double sum1 = 0.0;
double sum2 = 0.0;
double sum3 = 0.0;
double sum4 = 0.0;

//+------------------------------------------------------------------+
//| Stores the average price at each stage finish
//+------------------------------------------------------------------+
double avg1 = 0.0;
double avg2 = 0.0;
double avg3 = 0.0;
double avg = 0.0;

//+------------------------------------------------------------------+
//| Other usefule variables
//+------------------------------------------------------------------+
double NON_EXECUTED = 0.0;
double TOTAL_EXECUTED = 0.0;
double basic_execute_units = 1000.0;
double lot_units = 100000.0;
double openLots = 0.0;
double current_price = 0.0;
string db = "trade.db"; // databse name
int ticket = 0; // order ticke after every open order has been sent

//+------------------------------------------------------------------+
//| Time window Intervals
//+------------------------------------------------------------------+
// Time windows1
datetime startdt1 = D'2023.05.11 23:00:00';
datetime stopdt1 = D'2023.05.12 01:00:00';

// Time windows2
datetime startdt2 = D'2023.05.12 03:00:00';
datetime stopdt2 = D'2023.05.12 06:00:00';

// Time windows3
datetime startdt3 = D'2023.05.12 07:00:00';
datetime stopdt3 = D'2023.05.12 09:00:00';

// Time windows4
datetime startdt4 = D'2023.05.12 11:00:00';
datetime stopdt4 = D'2023.05.12 14:00:00';

// Time windows5, 30 mins after the fourth window
datetime startdt5 = D'2023.05.12 14:30:00';
datetime stodt5 = D'2023.05.12 15:00:00';

// Time windows6, 60 mins after the fourth window
datetime startdt6 = D'2023.05.12 15:00:00';

// to close orders in TWAP stage, we need to close the earliest order first,
// otherwise, oanda will not allow you to close.
int chooseOrder(){
    int totalOrders = OrdersTotal();
    datetime minTime = TimeCurrent();
    int idx = -1;

    // loop all orders and search the earliest index
    for(int i = 0; i < totalOrders; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            continue;
        }

        if(OrderSymbol() != Symbol())
        {
            continue;
        }
            
        if(OrderOpenTime() < minTime)
        {
            minTime = OrderOpenTime();
            idx = i;
        }
    }
    // return the min order index
    return idx;
}

// Write record into sqlite database
//void WriteToSqlite(int tk, string symbol, int type, double lots, datetime timestamp, double price) {
//   string query = "insert into trade (ticket, symbol, type, lots, timestamp, price) values (" + 
//       IntegerToString(tk) + ",'" + symbol + "'," + IntegerToString(type) + "," + 
//        DoubleToString(lots, 2) + ",'" + TimeToStr(timestamp, TIME_DATE|TIME_SECONDS) + "'," + 
//        DoubleToString(price, Digits) + ");";
//
//   sqlite_exec(db, query);
//}

// When Expert Advisor starts, it will check if there is a databse
// and create table accordingly
//int OnInit()
//{   
//    if (!sqlite_init()) {
//        return INIT_FAILED;
//    }

//    if (!sqlite_table_exists(db, Symbol()))
//    {
//        sqlite_exec(db, "CREATE TABLE trade (ticket, symbol, type, lots, timestamp, price)");
//    }    

//    return(INIT_SUCCEEDED);
//}

void OnDeinit(const int reason)
{
//   sqlite_finalize();
}

// Call OnTick when there is a new tick for the chart
void OnTick()
{
    static datetime dtLast = 0; // remember last order time to calculate time interval
    datetime dtCurrent = TimeCurrent(); // current date time

    // get current price
    if (isLong)
    {
        // for LONG, use ASK price
        current_price = MarketInfo(Symbol(), MODE_ASK);
    }
    else
    {
        // for SHORT, use BID price
        current_price = MarketInfo(Symbol(), MODE_BID);
    }

    //+------------------------------------------------------------------+
    //| Execution Window 1
    //+------------------------------------------------------------------+
    if (!finished1)
    {
        if (dtCurrent >= startdt1 && dtCurrent <= stopdt1 && dtCurrent - dtLast >= intervalSecs)// 360 secs interval
        {
            dtLast = dtCurrent;
            openLots = basic_execute_units/lot_units;
            if (isLong)
            {
                ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "HW5", 0, 0, Green);
              //  WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
            }
            else
            {
                ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "HW5", 0, 0, Green);
             //   WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
            }
            
            executed1 += basic_execute_units;
            sum1 += current_price * basic_execute_units;
            if (executed1 >= orderSize1)
            {
                finished1 = true;
            }
        }
    }
    
    // when window1 finished, calculate avg1
    if (dtCurrent > stopdt1 && avg1 == 0.0)
    {
        avg1 = sum1 / executed1;
        Print("avg1: ", avg1);
    }

    //+------------------------------------------------------------------+
    //| Execution Window 2
    //+------------------------------------------------------------------+
    if (!finished2)
    {
        if (dtCurrent >= startdt2 && dtCurrent <= stopdt2 && dtCurrent - dtLast >= intervalSecs)// 360 secs interval
        {
            dtLast = dtCurrent;

            openLots = basic_execute_units/lot_units;
            if (isLong && current_price >= avg1)
            {
                ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "HW5", 0, 0, Green);
             //   WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                executed2 += basic_execute_units;
                sum2 += current_price * basic_execute_units;
            }
            else if (!isLong && current_price <= avg1)
            {
                ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "HW5", 0, 0, Green);
           //     WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                executed2 += basic_execute_units;
                sum2 += current_price * basic_execute_units;
            }

            if (executed2 >= orderSize2)
            {
                finished2 = true;
            }
        }
    }
    
    // when window2 finished, calculate avg2
    if (dtCurrent > stopdt2 && avg2 == 0.0)
    {
        avg2 = (sum1 + sum2) / (executed1 + executed2);
        Print("avg2: ", avg2);
        NON_EXECUTED = orderSize1 + orderSize2 - executed1 - executed2;
        orderSize3 += NON_EXECUTED;
    }

    //+------------------------------------------------------------------+
    //| Execution Window 3
    //+------------------------------------------------------------------+
    if (!finished3)
    {
        if (dtCurrent >= startdt3 && dtCurrent <= stopdt3 && dtCurrent - dtLast >= intervalSecs)// 360 secs interval
        {
            dtLast = dtCurrent;

            openLots = orderSize3 / 20 / lot_units;
            if (isLong && current_price >= avg2)
            {
                ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "HW5", 0, 0, Green);
           //     WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                executed3 += openLots * lot_units;
                sum3 += current_price * openLots * lot_units;
            }
            else if (!isLong && current_price <= avg2)
            {
                ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "HW5", 0, 0, Green);
           //     WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                executed3 += openLots * lot_units;
                sum3 += current_price * openLots * lot_units;
            }

            if (executed3 >= orderSize3)
            {
                finished3 = true;
            }
        }
    }
    
    // when window3 finished, calculate avg3
    if (dtCurrent > stopdt3 && avg3 == 0.0)
    {
        avg3 = (sum1 + sum2 + sum3) / (executed1 + executed2 + executed3);
        Print("avg3: ", avg3);
        NON_EXECUTED = orderSize3 - executed3;
        orderSize4 += NON_EXECUTED;
    }

    //+------------------------------------------------------------------+
    //| Execution Window 4
    //+------------------------------------------------------------------+
    if (!finished4)
    {
        if (dtCurrent >= startdt4 && dtCurrent <= stopdt4 && dtCurrent - dtLast >= intervalSecs)// 360 secs interval
        {
            dtLast = dtCurrent;

            openLots = orderSize4 / 30 / lot_units;
            if (isLong && current_price >= avg3)
            {
                ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "HW5", 0, 0, Green);
           //     WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                executed4 += openLots * lot_units;
                sum4 += current_price * openLots * lot_units;
            }
            else if (!isLong && current_price <= avg3)
            {
                ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "HW5", 0, 0, Green);
           //     WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                executed4 += openLots * lot_units;
                sum4 += current_price * openLots * lot_units;
            }

            if (executed3 >= orderSize3)
            {
                finished4 = true;
            }
        }
    }
    
    // when window4 finished, calculate avg4
    if (dtCurrent > stopdt4 && TOTAL_EXECUTED == 0.0)
    {
        avg = (sum1 + sum2 + sum3 + sum4) / (executed1 + executed2 + executed3 + executed4);
        Print("avg: ", avg);

        NON_EXECUTED = orderSize4 - executed4;
        TOTAL_EXECUTED = executed1 + executed2 + executed3 + executed4;
        Print("Total Executed: ", TOTAL_EXECUTED, " Total Non-Executed: ", NON_EXECUTED);

        orderSize5 = 0.5 * NON_EXECUTED; // here we save the orderSize for window5: 50% non-executed
    }

    //+------------------------------------------------------------------+
    //| Execution Window 5: 30 minutes after execution window 4
    //+------------------------------------------------------------------+
    if (!finished5 && dtCurrent >= startdt5 && dtCurrent <= stodt5)
    {
        if (dtCurrent - dtLast >= intervalSecs)// 360 secs interval
        {
            dtLast = dtCurrent;

            openLots = orderSize5 / lot_units;
            if (isLong && current_price >= avg)
            {
                ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "", 0, 0, Green);
          //      WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                finished5 = true;
                Print("fifth Completed for 50%.");
            }
            else if (!isLong && current_price <= avg)
            {
                ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "", 0, 0, Green);
            //    WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                finished5 = true;
                Print("fifth Completed for 50%.");
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Execution Window 6: 60 minutes after execution window 4
    //+------------------------------------------------------------------+
    if (!finished6 && dtCurrent >= startdt6)
    { 
        // window5 has executed 50%, then we will check if we can execute the remaining 50% non-executed
        if (finished5)
        {
            if (dtCurrent - dtLast >= intervalSecs) // 360 secs interval
            {
                dtLast = dtCurrent;
                openLots = 0.5 * NON_EXECUTED / lot_units;
                if (isLong && current_price >= avg)
                {
                    ticket = OrderSend(Symbol(), OP_BUY, openLots, Ask, 1, 0, 0, "", 0, 0, Green);
            //        WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                    finished6 = true;
                    Print("window6 done 50%.");
                }
                else if (!isLong && current_price <= avg)
                {
                    ticket = OrderSend(Symbol(), OP_SELL, openLots, Bid, 1, 0, 0, "", 0, 0, Green);
             //       WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                    finished6 = true;
                    Print("window6 done 50%.");
                }
            }
        }
        else
        {
            // If the orders in window5 remain unexecuted at 50%, 
            // we will use TWAP to close them until the total execution reaches 20%
            if (TOTAL_EXECUTED <= 20000)
            {
                finished6 = true;
                Print("window6 Done");
            }
            else // twap by 1 minute started and not yet completed
            {
                if (dtCurrent - dtLast >= twap_interval) // 60 secs interval
                {
                    dtLast = dtCurrent;
                    int orderIndexToClose = chooseOrder();

                    // if we have found the earlist order, close it
                    if(orderIndexToClose != -1)
                    {
                        OrderSelect(orderIndexToClose, SELECT_BY_POS, MODE_TRADES);

                        if(OrderType() == OP_BUY)
                        {
                            ticket = OrderTicket();
                            openLots = OrderLots();
                            OrderClose(ticket, openLots, Bid, 1, clrRed);
                   //         WriteToSqlite(ticket, Symbol(), OP_SELL, openLots, dtCurrent, current_price);
                            TOTAL_EXECUTED -= openLots * lot_units;
                        }
                        else if(OrderType() == OP_SELL)
                        {
                            ticket = OrderTicket();
                            openLots = OrderLots();
                            OrderClose(ticket, openLots, Ask, 1, clrRed);
                    //        WriteToSqlite(ticket, Symbol(), OP_BUY, openLots, dtCurrent, current_price);
                            TOTAL_EXECUTED -= openLots * lot_units;
                        }
                    }
                }
            }
        }
    }
}