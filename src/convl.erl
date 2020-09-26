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
-export([conv/2,conv1/0]).






conv(Nm,PyPID)->

  Result=python:call(PyPID, conv, convolution, [Nm]), %%todo: we need to draw for a time
  io:fwrite("recieved message from python ~p~n", [Result])%% todo: easy to call server by node and Pid name


.


conv1()->

  %%Result=python:call(PyPID, conv, convolution, [Nm]), %%todo: we need to draw for a time
  io:fwrite("convoloution in progress !!!!!!!n ~n", []),%% todo: easy to call server by node and Pid name
  [1,4,9,16]


.

