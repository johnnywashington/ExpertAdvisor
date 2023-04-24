Robô para fazer operações no Mini Indice
//+------------------------------------------------------------------+
//|                                              Robo JC segundo.mq5 |
//|                                       Johnny Washington Jc robos |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Johnny Washington Jc robos"
#property link      "https://www.Jcrobos.com.br"
#property version   "1.00"
//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh> // biblioteca-padrão Ctrade
//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
enum conta_
   {
    conta_1 = Real
    conta_2 = Demo
   };
input conta_ InputConta = conta_1;//Conta
input int lote = 1;//contratos 
input int periodoCurta = 13;// Media curta
input int periodoLonga = 41;// Media longa
input ulong magicNum = 123456;// Magic number
input ulong desvPts = 100;// Desvio de pontos
input double stopLoss = 5;// StopLoss(Pontos)
input double takeProfit = 3;// StopGain(Pontos)
input double trailling = 1; // trailling(Pontos)

input int horaInicioAbertura = 15;//hora inicio de abertura de posições
input int minutoInicioAbertura = 0;//minuto inicio de abertura de posições
input int horaFimAbertura = 16;//hora de encerramento de abertura de posições
input int minutofimAbertura = 05;//minuto de encerramento de abertura de posições
input int horaInicioFechamento = 17;//hora inicio de fechamento 
input int minutoInicioFechamento = 0;//minuto inicio de fechamento

int posicoes; 

double ask, bid, last;
double smaArray[];
                
MqlDateTime horaAtual;

//+------------------------------------------------------------------+
//| GLOBAIS                                                          |
//+------------------------------------------------------------------+ 
//--- manipuladores dos indicadores de média móvel
int curtaHandle = INVALID_HANDLE;
int longaHandle = INVALID_HANDLE;
//--- vetores de dados dos indicadores de média móvel
double mediaCurta[];
double mediaLonga[];
//--- declarar variavel trade
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    if(AccountInfoInteger(ACCOUNT_LOGIN) != InputConta)
      {
       Alert("Não é permitido nessa conta");
       return(INIT_FAILED);
      }
      
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetDeviationInPoints(desvPts);
   trade.SetExpertMagicNumber(magicNum);
   
   if(horaInicioAbertura > horaFimAbertura || horaFimAbertura > horaInicioFechamento)
     {
      Alert("inconsistencia de horario!");
      return(INIT_FAILED);
     }
     
   if(horaInicioAbertura == horaFimAbertura && minutoInicioAbertura >= minutofimAbertura)
     {
      Alert("inconsistencia de horario!");
      return(INIT_FAILED);
     }
     
   if(horaFimAbertura == horaInicioFechamento && minutofimAbertura >= minutoInicioAbertura)
     {
      Alert("inconsistencia de horario!");
      return(INIT_FAILED);
     }
     
   //---
   ArraySetAsSeries(mediaCurta,true);
   ArraySetAsSeries(mediaLonga,true);
    
    //---atribuir valores para os manipuladores de media movel
   curtaHandle = iMA(_Symbol,_Period,periodoCurta,0,MODE_EMA,PRICE_CLOSE);
   longaHandle = iMA(_Symbol,_Period,periodoLonga,0,MODE_EMA,PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
   
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

      //--- execute a logica operacional do robo
      //+------------------------------------------------------------------+
      //| OBTENÇÃO DE DADOS                                                |
      //+------------------------------------------------------------------+
     
      bool novaBar = isNewBar();
      
      TimeToStruct(TimeCurrent(), horaAtual);
      Comment("hora Atual: ", horaAtual.hour, "\nMinuto Atual: ", horaAtual.min);
      
      
     if(HoraFechamento())
         {
          Comment("horario de Fechamento de Posições!");
          FechaPosicao();
         }
      
     else if(HoraNegociacao())
        {
         Comment("dentro do horario de negociação!");
        }
     else
        {
         Comment("fora do horario de negociação!");
         DeletaOrdens();
        }
      ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      last = SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      
      int copied1 = CopyBuffer(curtaHandle,0,0,3,mediaCurta);
      int copied2 = CopyBuffer(longaHandle,0,0,3,mediaLonga);
      //---
      bool sinalCompra = false;
      bool sinalVenda = false;
      //--- se os dados tiverem sido copiados corretamente 
      if(copied1==3 && copied2==3)
        {
         //--- sinal de compra 
         if(mediaCurta[1]>mediaLonga[1] && mediaCurta[2]<mediaLonga[2] && HoraNegociacao() && novaBar)
           { 
            sinalVenda = true;
           }
         //--- sinal de venda
         if(mediaCurta[1]<mediaLonga[1] && mediaCurta[2]>mediaLonga[2] && HoraNegociacao() && novaBar)
           { 
            sinalCompra = true;
           }
        }
      
     //+------------------------------------------------------------------+
     //| verificar se estou posicionado                                   |
     //+------------------------------------------------------------------+
     bool comprado = false;
     bool vendido = false;
     if(PositionSelect(_Symbol))
       {
        //--- se a posição for comprada
        if( PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY )
          {
           comprado = true;
          }
        //--- se a posição for vendida
        if( PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL )
          {
            vendido = true;
          }
       }
     //---Trailling
     if( PositionsTotal() > 0)
       {
        PositionSelect(_Symbol);
         ulong ticket = PositionGetTicket(0);
           if(( PositionGetDouble(POSITION_PRICE_CURRENT) - PositionGetDouble(POSITION_PRICE_OPEN)) > trailling+1)
             {
              if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY )
                {
                 if(trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN) + trailling, PositionGetDouble(POSITION_PRICE_OPEN) + takeProfit))
                   {
                    Print("traillinstop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                   }
                 else
                   {
                    Print("traillinstop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                   }
                 
                }
              }
              if(( PositionGetDouble(POSITION_PRICE_CURRENT) - PositionGetDouble(POSITION_PRICE_OPEN)) < trailling+1)
                {
             
                 if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL )
                   {
                   if(trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN) - trailling, PositionGetDouble(POSITION_PRICE_OPEN) - takeProfit))
                     {
                      Print("traillinstop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                     }
                   else
                     {
                      Print("traillinstop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                     }
                          
                }
               }
             
    
       }
      
     //+------------------------------------------------------------------+
     //| LOGICA DE ROTEAMENTO                                             |
     //+------------------------------------------------------------------+
     //--- ZERADO
   
     if( !comprado && !vendido )
       {
        //--- sinal de compra
        if( sinalCompra )
          {
           trade.Buy(lote,_Symbol,ask,ask-stopLoss,ask+takeProfit,"Compra a mercado");
          }
        //--- sinal de venda
        if( sinalVenda )
          {
           trade.Sell(lote,_Symbol,bid,bid+stopLoss,bid-takeProfit,"venda a mercado");
          }
       }  
      else
       {
        //--- estou comprado 
        if( comprado )
          { 
           if( sinalVenda )
             { 
              trade.Sell(lote,_Symbol,bid,bid+stopLoss,bid-takeProfit,"virada de mão (compra->venda)");
             }
          }
        //--- estou vendido
        else if( vendido )
          {
           if( sinalCompra )
             {
              trade.Buy(lote,_Symbol,ask,ask-stopLoss,ask+takeProfit,"virada de mão ( venda->compra)");
             }
          }
       }
     
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
   {
//--- memorize the time of opening of the last bar in the static variable
    static datetime last_time=0;
//--- current time 
    datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   
//--- if it is the first call of the function
    if(last_time==0)
      {
       //--- set the time and exit
       last_time=lastbar_time;
       return(false);
      }
   
//--- if the time differs
    if(last_time!=lastbar_time)
      {
       //--- memorize the time and return true
       last_time=lastbar_time;
        return(true);
      }
//--- if we passed to this line, then the bar is not new, return false
    return(false);
   } 
//---
bool HoraFechamento()
   {
    TimeToStruct(TimeCurrent(), horaAtual);
    if(horaAtual.hour >= horaInicioFechamento)
      {
       if(horaAtual.hour == horaInicioFechamento)
         {
          if(horaAtual.min >= minutoInicioFechamento)
            { 
             return true;
            }
          else
            {
             return false;
            }
         }
        return true;
      }
    return false; 
   }
//---
bool HoraNegociacao()
   {
    TimeToStruct(TimeCurrent(), horaAtual);
    if(horaAtual.hour >= horaInicioAbertura && horaAtual.hour <= horaFimAbertura)
      {
        if(horaAtual.hour == horaInicioAbertura)
          {
            if(horaAtual.min >= minutoInicioAbertura)
                {
               return true;
              }
           else
              {
               return false;
              }
          }
        if(horaAtual.hour == horaFimAbertura)
          {
            if(horaAtual.min <= minutofimAbertura)
              {
               return true;
              }
           else
              {
               return false;
              }
          }
        return true;
      }
    return false;
   
   }
//---
void FechaPosicao() 
   {
    for(int i = PositionsTotal()-1; i>=0; i--)
       {
        string symbol = PositionGetSymbol(i);
        ulong magic = PositionGetInteger(POSITION_MAGIC);
        if(symbol == _Symbol && magic == magicNum)
          {
           ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
            if(trade.PositionClose(PositionTicket, desvPts))
              {
               Print("Posicao fechada - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
              }
           else
              {
               Print("Posicao fechada - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
              }
          }
       }
   }

//---
void DeletaOrdens()
   {
    for(int i = OrdersTotal()-1; i>=0; i--)
       {
        ulong ticket = OrderGetTicket(i);
        string symbol = OrderGetString(ORDER_SYMBOL);
        ulong magic = OrderGetInteger(ORDER_MAGIC);
        if(symbol == _Symbol && magicNum)
          {
            if(trade.OrderDelete(ticket))
              {
               Print("Ordem Deletada - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
              }
           else
              {
               Print("Ordem Deletada - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
              }
          }
       }
   }
//---