%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 23. Sep 2020 14:48
%%%-------------------------------------------------------------------
-module(graphs).
-author("kyan").

%% API
-export([init/0,draw/2,start/0]).


init()->


  Pid = spawn(graphs, start,[]),
  register(graph,Pid)



.

start()->

  {ok, P} = python:start([{python_path, "test.py"},{python, "python3"}]),

  graphHanlder(P)
.

draw(Nm,PyPID)->


  Result=python:call(PyPID, test, print, [Nm]), %%todo: we need to draw for a time
  case Result of
    1->1;%% todo: send finished to the server
    _->0%% todo : there is a problem neee dto fix it if there is no result
  end

.


graphHanlder(P)->


  PyPID=P,
  io:fwrite("the pid is~p~n", [PyPID]),



  receive

  % a connection get the close_window signal
  % and sends this message to the server


  %% recieveing mesagews
  %% io:fwrite("recieved message from server to start drawing ~n", []),%% todo: easy to call server by node and Pid namefrom out server
    {server,draw,Nm}->
      io:fwrite("recieved message from server to start drawing ~n", []),%% todo: easy to call server by node and Pid name
      io:fwrite("drawing...... ~n", []),
      Res=draw(Nm,PyPID),
      case Res of%% todo:: is blocking way to draw you need to exit hte window to move
        1-> io:fwrite("end drawing ........~n", []),
          spawn(server,endTest,[server,'serverNode@127.0.0.1',1]);
        %%spawn(server,endTest,[server,'serverNode@127.0.0.1',1]);
        _->io:fwrite("the Result is is~p~n", [Res])
      end,

      graphHanlder(P);



    {server,terminate}->%% todo!!!
      1;





    _->1



  end

.