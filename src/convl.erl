%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 24. Sep 2020 10:28
%%%-------------------------------------------------------------------
-module(convl).
-author("kyan").

%% API
-export([init/0,conv/1,start/0]).



init()->
  {ok, Py} = python:start([{python_path, "conv.py"},{python, "python3"}]),
  put(py,Py),
  Pid = spawn(convl, start,[]),
  register(conv,Pid)
.


start() ->
  convHandler()
  .



conv(Nm)->

  Pid=get(py),
  Result=python:call(Pid, conv, convolution, [Nm]), %%todo: we need to draw for a time
  io:fwrite("recieved message from python ~p~n", [Result])%% todo: easy to call server by node and Pid name
.

convHandler()->

  receive
  % a connection get the close_window signal
  % and sends this message to the server


  %% recieveing mesagews from out server
  {gui,conv}->
  io:fwrite("recieved message from gui to translate ~n", []),%% todo: easy to call server by node and Pid name
    convHandler();

  {server,terminate}->
  1;

  _->1

  end
.