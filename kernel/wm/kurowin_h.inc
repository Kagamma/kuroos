  PKuroBody = ^TKuroBody;
  TKuroBody = object(TKuroView)
    constructor Init(const AParent: PKuroObject);
  end;

  PKuroButton = ^TKuroButton;
  TKuroButton = object(TKuroView)
    TextX, TextY: LongInt;
    procedure SetSize(const AWidth, AHeight: Cardinal); virtual;
    procedure SetName(const AName: ShortString); virtual;
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