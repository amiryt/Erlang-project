-module(wxd).
-author("KyanSleem").
-compile(export_all).
-include_lib("wx/include/wx.hrl").


init()->
  Pid = spawn(wxd, start,[]),
  register(gui,Pid),
  put(servernode,'serverNode@127.0.0.1').


start() ->
  State = make_window(),
  put(isactive,0),
  put(servernode,'serverNode@127.0.0.1'),
  loop (State),
  wx:destroy().


make_window() ->
  Server = wx:new(),
  Frame = wxFrame:new(Server, -1, "SNN", [{size,{400, 600}}]),
  Panel  = wxPanel:new(Frame),
  MainSizer = wxBoxSizer:new(?wxVERTICAL),
  TextSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel,
    [{label, "How to use"}]),
  BitmapSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 1"}]),
  BitmapSizer1 = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 2"}]),
  BitmapSizer2 = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 3"}]),

  %% Create static texts
  Texts = [wxStaticText:new(Panel, 1, "info", []),
    wxStaticText:new(Panel, 2, "info",
      [{style, ?wxALIGN_CENTER bor ?wxST_NO_AUTORESIZE}]),
    wxStaticText:new(Panel, 3, "info",
      [{style, ?wxALIGN_RIGHT bor ?wxST_NO_AUTORESIZE}])],

  Image = wxImage:new("0.jpg", []),
  Bitmap = wxBitmap:new(wxImage:scale(Image,
    round(wxImage:getWidth(Image)*4),
    round(wxImage:getHeight(Image)*4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap = wxStaticBitmap:new(Panel, 1, Bitmap),

  Image1 = wxImage:new("1.jpg", []),
  Bitmap1 = wxBitmap:new(wxImage:scale(Image1,
    round(wxImage:getWidth(Image1)*4),
    round(wxImage:getHeight(Image1)*4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap1 = wxStaticBitmap:new(Panel, 2, Bitmap1),

  Image2 = wxImage:new("2.jpg", []),
  Bitmap2 = wxBitmap:new(wxImage:scale(Image2,
    round(wxImage:getWidth(Image2)*4),
    round(wxImage:getHeight(Image2)*4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap2 = wxStaticBitmap:new(Panel, 3, Bitmap2),

  %% Add to sizers
  [wxSizer:add(TextSizer, Text, [{flag, ?wxEXPAND bor ?wxALL},
    {border, 10}]) || Text <- Texts],

  wxSizer:add(BitmapSizer, StaticBitmap, []),
  wxSizer:add(BitmapSizer1, StaticBitmap1, []),
  wxSizer:add(BitmapSizer2, StaticBitmap2, []),
  wxSizer:add(MainSizer, TextSizer, [{flag, ?wxEXPAND}]),
  wxSizer:add(MainSizer, BitmapSizer, []),
  wxSizer:add(MainSizer, BitmapSizer1, []),
  wxSizer:add(MainSizer, BitmapSizer2, []),

%% Create widgets
%% The order entered here does not control appearance
  T1001 = wxTextCtrl:new(Panel, 1001,[{value, "1"}]), %set default value
  ST2001 = wxStaticText:new(Panel, 2001,"Output Area",[]),
  ST2002 = wxStaticText:new(Panel, 2001,"Chose input image",[]),
  B101  = wxButton:new(Panel, 101, [{label, "&Send"}]),%% 101 is the id
  B102  = wxButton:new(Panel, ?wxID_EXIT, [{label, "E&xit"}]),%% ?wxId_EXIT

  OuterSizer  = wxBoxSizer:new(?wxHORIZONTAL),
  InputSizer  = wxBoxSizer:new(?wxVERTICAL),%%% distance from up of the frame
  ButtonSizer = wxBoxSizer:new(?wxHORIZONTAL),

  wxSizer:add(InputSizer, ST2002, []),
  wxSizer:add(InputSizer, 40, 0, []),

  wxSizer:addSpacer(MainSizer, 10),  %spacer
  wxSizer:add(InputSizer, T1001, []),
  wxSizer:addSpacer(MainSizer, 5),  %spacer

  wxSizer:addSpacer(MainSizer, 10),  %spacer
  wxSizer:add(MainSizer, InputSizer,[]),
  wxSizer:addSpacer(MainSizer, 5),  %spacer

  wxSizer:add(MainSizer, ST2001, []),
  wxSizer:addSpacer(MainSizer, 10),  %spacer

  wxSizer:add(ButtonSizer, B101,  []),
  wxSizer:add(ButtonSizer, B102,  []),
  wxSizer:add(MainSizer, ButtonSizer, []),

  wxSizer:addSpacer(OuterSizer, 20), % spacer
  wxSizer:add(OuterSizer, MainSizer, []),

  wxPanel:setSizer(Panel, OuterSizer),
  wxFrame:show(Frame),

% Create two listeners
  wxFrame:connect( Frame, close_window),
  wxPanel:connect(Panel, command_button_clicked),

%% the return value, which is stored in State
  {Frame, T1001, ST2001}.

loop(State) ->
  {Frame, T1001, ST2001}  = State,
  io:format("------ Waiting in the loop ------~n", []),
  receive
    {server,finished}->
      put(isactive,0),
      wxStaticText:setLabel(ST2001, "Enter an option"),
      io:fwrite("Recieved message finished message ~n", []),
      loop(State);

    %% Receiving messages from out server
    {server,Msg}->
      io:fwrite("Recieved message ~n", []),
      loop(State);

    #wx{event=#wxClose{}} ->
      io:format("~p Closing window ~n",[self()]),
      wxWindow:destroy(Frame),
      ok;

    #wx{id = ?wxID_EXIT, event=#wxCommand{type = command_button_clicked} } ->
      io:format("~p Closing window ~n",[self()]),
      wxWindow:destroy(Frame),
      ok;

    #wx{id = 101, event=#wxCommand{type = command_button_clicked}} ->
      T1001_val = wxTextCtrl:getValue(T1001),
      case is_valid_list_to_integer(T1001_val) of
        true ->
          case get(isactive) of

          0->
          case list_to_integer(T1001_val) of
            1->put(isactive,1),
              spawn(server,testImage,[server,'serverNode@127.0.0.1',0]),
              wxStaticText:setLabel(ST2001, "The network in progress please wait"),
              io:fwrite("Sends a signal of the picture num One~n", []);

            2->put(isactive,1),
              spawn(server,testImage,[server,'serverNode@127.0.0.1',1]),
              wxStaticText:setLabel(ST2001, "The network in progress please wait"),
              io:fwrite("Sends a signal of the picture num Two~n", []);

            3->put(isactive,1),
              spawn(server,testImage,[server,'serverNode@127.0.0.1',2]),
              wxStaticText:setLabel(ST2001, "The network in progress please wait"),
              io:fwrite("Sends a signal of the picture num Three~n", []);
            _-> wxStaticText:setLabel(ST2001, "Invalid input, Please choose again")
          end;

          _->wxStaticText:setLabel(ST2001, "The network in progress please wait")
          end;

        _ ->
          wxStaticText:setLabel(ST2001, "Only integers are allowed!")
      end,
      loop(State);

    Msg ->
      io:format("Loop default triggered: Got ~n ~p ~n", [Msg]),
      loop(State)
  end.

cntdwn(N,StaticText) when N > 0 ->
  io:format("~w~n", [N]),
  OutputStr = integer_to_list(N),
  wxStaticText:setLabel(StaticText, OutputStr),
  receive
  after 1000 ->
    true
  end,
  cntdwn(N-1, StaticText);
cntdwn(_, StaticText) ->
  io:format("ZERO~n"),
  OutputStr = "ZERO",
  wxStaticText:setLabel(StaticText, OutputStr),
  ok.


is_valid_list_to_integer(Input) ->
  try list_to_integer(Input) of
    _An_integer -> true
  catch
    error: _Reason -> false
  end.



    