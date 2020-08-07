%%%-------------------------------------------------------------------
%%% @author Amir
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. אוג׳ 2020 11:11
%%%-------------------------------------------------------------------
-module(neuron_wxwidget).
-author("Amir").

%% API
-export([start/0]).
-include_lib("wx/include/wx.hrl").

%% In this code we will design the WxWidget of the neuron %%

%%TODO: Make that a process that starts when the program is starting to run
start() ->
  info_message("Hello world").



%% @doc Receives: Msg - A string with the information we want to print
%%      Returns:  Printing the message on the screen
%% Information messages %%
info_message(Msg) -> wx:new(), % New wx server instance
  M = wxMessageDialog:new(wx:null(), Msg),
  wxMessageDialog:showModal(M).