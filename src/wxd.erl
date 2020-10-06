-module(wxd).
-author("KyanSleem").
-compile(export_all).
-include_lib("wx/include/wx.hrl").


init()->
  Pid = spawn(wxd, start,[]),
  register(gui,Pid),
  Pid
.



start() ->
  State = make_window(),
  put(isactive,0),

  %%io:fwrite("I am the shell now monitor motherfucker !~n",[]),
  put(servernode,'serverNode@127.0.0.1'),
  loop (State), %% need to make a spawn function to recieve from the server

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


  Image = wxImage:new("image0.jpg", []),
  Bitmap = wxBitmap:new(wxImage:scale(Image,
    round(wxImage:getWidth(Image)*4),
    round(wxImage:getHeight(Image)*4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap = wxStaticBitmap:new(Panel, 1, Bitmap),

  Image1 = wxImage:new("image1.jpg", []),
  Bitmap1 = wxBitmap:new(wxImage:scale(Image1,
    round(wxImage:getWidth(Image1)*4),
    round(wxImage:getHeight(Image1)*4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap1 = wxStaticBitmap:new(Panel, 2, Bitmap1),


  Image2 = wxImage:new("image2.jpg", []),
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






%% create widgets
%% the order entered here does not control appearance
  T1001 = wxTextCtrl:new(Panel, 1001,[{value, "1"}]), %set default value
  ST2001 = wxStaticText:new(Panel, 2001,"Output Area",[]),
  ST2002 = wxStaticText:new(Panel, 2001,"Chose input image",[]),



  B100  = wxButton:new(Panel, 100, [{label, "Draw"}]),%% 101 is the id
  B101  = wxButton:new(Panel, 101, [{label, "&Send"}]),%% 101 is the id
  %%B104  = wxButton:new(Panel, 104, [{label, "&IMG2"}]),%% 101 is the id
  %%B105  = wxButton:new(Panel, 105, [{label, "&SIMG3"}]),%% 101 is the id
  %%B106  = wxButton:new(Panel, 106, [{label, "&SIMG4"}]),%% 101 is the id



%%  B107  = wxButton:new(Panel, 107, [{label, "&IMG5"}]),%% 101 is the id
  B102  = wxButton:new(Panel, ?wxID_EXIT, [{label, "E&xit"}]),%% ?wxId_EXIT






%%You can create sizers before or after the widgets that will go into them, but
%%the widgets have to exist before they are added to sizer.
  OuterSizer  = wxBoxSizer:new(?wxHORIZONTAL),

  InputSizer  = wxBoxSizer:new(?wxVERTICAL),%%% distance from up of the frame
  ButtonSizer = wxBoxSizer:new(?wxHORIZONTAL),
  ButtonSizerD=wxBoxSizer:new(?wxVERTICAL),





  %% HORIZON left and wirte
  %% VERT UP and DOWN


%% Note that the widget is added using the VARIABLE, not the ID.
%% The order they are added here controls appearance.




  %% wxSizer:add(ImageSizer, StaticBitmap, []),
  %%wxSizer:add(ImageSizer, StaticBitmap1, []),
  %%wxSizer:add(ImageSizer, StaticBitmap2, []),

  %%wxSizer:add(InputSizer1, ImageSizer, []),






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
  wxSizer:add(ButtonSizerD, B100,  []),
  wxSizer:add(MainSizer, ButtonSizerD, []),
  wxSizer:add(ButtonSizer, B101,  []),
  wxSizer:add(ButtonSizer, B102,  []),
  wxSizer:add(MainSizer, ButtonSizer, []),

  wxSizer:addSpacer(OuterSizer, 20), % spacer
  wxSizer:add(OuterSizer, MainSizer, []),


%% Now 'set' OuterSizer into the Panel


  wxPanel:setSizer(Panel, OuterSizer),

  wxFrame:show(Frame),

% create two listeners
  wxFrame:connect( Frame, close_window),
  wxPanel:connect(Panel, command_button_clicked),

%% the return value, which is stored in State
  {Frame, T1001, ST2001}.

loop(State) ->
  {Frame, T1001, ST2001}  = State,  % break State back down into its components
  %%io:format("--waiting in the loop--~n", []), % optional, feedback to the shell

  receive

  % a connection get the close_window signal
  % and sends this message to the server


    {server,finished}->
      put(isactive,0),
      wxStaticText:setLabel(ST2001, "you can inter"),
      %%:fwrite("recieved message finished message ~n", []),%% todo: easy to call server by node and Pid name
      loop(State);

  %% recieveing mesagews from out server
    {monitor,exit}->ok;
      %%:fwrite("recieved exit message I wxd  ~n", []);
  % wxWindow:destroy(Frame);%% todo: easy to call server by node and Pid name



    #wx{event=#wxClose{}} ->
      %%:format("~p Closing window ~n",[self()]), %optional, goes to shell
      %now we use the reference to Frame
      wxWindow:destroy(Frame),  %closes the window
      ok;  % we exit the loop

    #wx{id = ?wxID_EXIT, event=#wxCommand{type = command_button_clicked} } ->
      %%     {wx, ?wxID_EXIT, _,_,_} ->
      %this message is sent when the exit button (ID 102) is clicked
      %the other fields in the tuple are not important to us.
      %%:format("~p Closing window ~n",[self()]), %optional, goes to shell
      wxStaticText:setLabel(ST2001, "closing the application!,"),
      timer:sleep(2000),%% todo : wait to send message to the monitor to end the application {gui,terminate}
      wxWindow:destroy(Frame),
      ok;  % we exit the loop

    #wx{id = 100, event=#wxCommand{type = command_button_clicked}} ->
      wxStaticText:setLabel(ST2001, "DRAWING: at the end press save, then exit!"),
      {ok, PyPID} = python:start([{python_path, "conv.py"},{python, "python3"}]),
      python:call(PyPID, paint, draw, []),
      wxStaticText:setLabel(ST2001, " choose option number 4, to send the drawed Image"),

      loop(State);

    #wx{id = 101, event=#wxCommand{type = command_button_clicked}} ->
      %this message is sent when the Countdown button (ID 101) is clicked
      T1001_val = wxTextCtrl:getValue(T1001),%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%getting the value from the box
      case is_valid_list_to_integer(T1001_val) of
        true ->
          case get(isactive) of

            0->
              case list_to_integer(T1001_val) of
                1->put(isactive,1),
                  spawn(server,testImage,[server,'serverNode@127.0.0.1',conv1(0)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");
                  %%:fwrite("send a signal of  the picture num One~n", []);%% todo : send to convolution and stop receiveing commands
                %%loop(State);
                2->put(isactive,1),

                  spawn(server,testImage,[server,'serverNode@127.0.0.1',conv1(1)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");
                  %%:fwrite("send a signal of  the picture num Two~n", []);

                3->put(isactive,1),
                  spawn(server,testImage,[server,'serverNode@127.0.0.1',conv1(2)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");
                  %%:fwrite("send a signal of  the picture num Three~n", []);%%%......

                4->put(isactive,1),
                  spawn(server,testImage,[server,'serverNode@127.0.0.1',conv1(3)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");


                  %%:fwrite("send a signal of  the drawed picture~n", []);%%%......
                _-> wxStaticText:setLabel(ST2001, "Invalid input, Please chose again")
              end;
            %% T1001_int = list_to_integer(T1001_val),
            %%cntdwn(T1001_int, ST2001);  %letting cntdwn/2 fill in the textbox

            _->wxStaticText:setLabel(ST2001, "The network in progress please wait")
          end;
        _ ->
          wxStaticText:setLabel(ST2001, "Only integers are allowed")
      end,


      loop(State);

    Msg ->ok
      %everything else ends up here
      %%:format("loop default triggered: Got ~n ~p ~n", [Msg])
  %loop(State)

  end.

cntdwn(N,StaticText) when N > 0 ->
  % assumes N is an integer
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
    error: _Reason -> false  %Reason is badarg
  end.





conv1(ImageNum)->

  %%Result=python:call(PyPID, conv, convolution, [Nm]), %%todo: we need to draw for a time
  {ok, PyPID} = python:start([{python_path, "conv.py"},{python, "python3"}]),
  %%:fwrite("convoloution in progress !!!!!!! ~n", []),%% todo: easy to call server by node and Pid name
  Result=python:call(PyPID, conv, getImageTraing, [ImageNum]), %%todo: we need to draw for a time

  Result

.

    