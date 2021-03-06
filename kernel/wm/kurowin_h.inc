  PKuroBody = ^TKuroBody;
  TKuroBody = object(TKuroView)
    constructor Init(const AParent: PKuroObject);
  end;

  PKuroButton = ^TKuroButton;
  TKuroButton = object(TKuroView)
    TextX, TextY: LongInt;
    procedure SetSize(const AWidth, AHeight: Cardinal); virtual;
    procedure SetName(const AName: PChar); virtual;
    procedure Render; virtual;
  end;

  PKuroCloseButton = ^TKuroCloseButton;
  TKuroCloseButton = object(TKuroView)
    TextX, TextY: LongInt;
    procedure Callback(const M: PKuroMessage); virtual;
    procedure Render; virtual;
  end;

  PKuroWindow = ^TKuroWindow;
  TKuroWindow = object(TKuroView)
    Body: PKuroBody;
    BtnClose: PKuroCloseButton;
    constructor Init(const AParent: PKuroObject);
    destructor Done; virtual;
    procedure Callback(const M: PKuroMessage); virtual;
    procedure Render; virtual;
    procedure SetPosition(const AX, AY: LongInt); virtual;
    procedure SetSize(const AWidth, AHeight: Cardinal); virtual;
  end;

  PKuroImage = ^TKuroImage;
  TKuroImage = object(TKuroView)
    Buffer: GLuint;
    constructor Init(const AParent: PKuroObject);
    destructor Done; virtual;
    procedure Render; virtual;
    procedure SetImage(const AName: PChar); virtual;
    procedure ProcessMessages(const M: PKuroMessage; const IsChild: Boolean); virtual;
  end;