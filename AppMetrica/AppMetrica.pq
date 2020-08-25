// This file contains your Data Connector logic
section AppMetrica;

[DataSource.Kind="AppMetrica", Publish="AppMetrica.Publish"]
shared AppMetrica.Stat = Value.ReplaceType(AppMetrica.Data, FuncType);

FuncType = type function (
      id  as (type text meta [
        Documentation.FieldCaption = "AppMetrica ID:",
        Documentation.FieldDescription = "Enter your AppMetrica ID.",
        Documentation.SampleValues = {"123456"}
    ]),
    start as (type text meta [
        Documentation.FieldCaption = "Start date:",
        Documentation.FieldDescription = "Enter the first date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"2020-02-28"}
    ]),
     end as (type text meta [
        Documentation.FieldCaption = "End date:",
        Documentation.FieldDescription = "Enter the last date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"yesterday"}
    ]),
     optional custom as (type text meta [
        Documentation.FieldCaption = "API request:",
        Documentation.FieldDescription = "Enter your API request for graph or table.",
        Documentation.SampleValues = {"https://api.appmetrica.yandex.ru/stat/v1/data/bytime?lang=ru&filters=&id=123&date1=2020-08-19&date2=2020-08-25&group=day&metrics=ym%3Au%3AactiveUsers&limit=7&include_undefined=true&row_ids=%5B%5D&accuracy=1&proposedAccuracy=true"}
    ]),
      optional metrics as (type text meta [
        Documentation.FieldCaption = "Metrics:",
        Documentation.FieldDescription = "Enter a comma-separated list of metrics.",
        Documentation.SampleValues = {"ym:ge:users,ym:ge:sessions"}
    ]),
     optional dimensions as (type text meta [
        Documentation.FieldCaption = "Dimensions:",
        Documentation.FieldDescription = "Enter a comma-separated list of dimensions.",
          Documentation.SampleValues = { "ym:ge:appID,ym:ge:appVersion"}
    ])

    )
    as table meta [
        Documentation.Name = "AppMetrica Stat",
        Documentation.LongDescription = 
        "Created to get data from AppMetrica service. 
        Use all dimensions and metrics from AppMetrica reference.
        Get the full list of dimensions and metrics in the last example below.",
        Documentation.Examples = {
        [
            Description = "Use your list of dimensions and metrics:",
            Code = "AppMetrica.Stat(""123456"", ""2020-08-01"", ""yesterday"", null, ""ym:ge:users,ym:ge:sessions"", ""ym:ge:appID,ym:ge:appVersion"")",
            Result = "Table with 4 columns"
        ],
        [
            Description = "Take the API request from AppMetrica export:",
            Code = "AppMetrica.Stat(""123456"", ""2020-08-01"", ""yesterday"", ""https://api.appmetrica.yandex.ru/stat/v1/data/bytime?lang=ru&request_domain=ru&filters=gender%20IN('male'%2C'female')&id=123456&date1=2020-07-01&date2=2020-07-01&group=hour&metrics=ym%3Au%3AactiveUsers&limit=25&include_undefined=true&row_ids=%5B%5D&accuracy=1&proposedAccuracy=true"", null, null)",
            Result ="Custom report from AppMetrica, according to API request."
        ],
        [
            Description = "Copy this url to know about all dimensions and metrics:",
            Code = "https://appmetrica.yandex.com/docs/mobile-api/api_v1/attributes/",
            Result = "The best report!"
        ]
        }
    ];


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1000;
windowHeight = 800;


AppMetrica.Data = (id as text,  start as text,  end as text,    optional custom as text, optional metrics as text, optional dimensions as text)=>
    let
url = if custom = null then "https://api.appmetrica.yandex.ru/stat/v1/data.csv" else Text.BeforeDelimiter(custom, "?")&".csv",
dim = if dimensions=null then "" else dimensions,
met = if metrics=null then "ym:u:activeUsers" else metrics,
get =   if custom = null then  [#"metrics"=met, #"dimensions"=dim, #"id"=id, #"date1"=dateFunc(start), #"date2"=dateFunc(end)] else 
params(custom) & [#"id"=id, #"date1"=dateFunc(start), #"date2"=dateFunc(end)] ,
headers = [#"Authorization"="OAuth "&Extension.CurrentCredential()[access_token]],
web = Web.Contents(url, [Query = get, Headers = headers, ManualStatusHandling = {404, 400}]),
result = Csv.Document(web)
in Table.PromoteHeaders(result,  [PromoteAllScalars=true]);
    

params = (get)=>
let
  #"Разделение текста" = Text.Split(get, "&"),
    #"Преобразовано в таблицу" = Table.FromList(#"Разделение текста", Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Извлеченный текст после разделителя" = Table.TransformColumns(#"Преобразовано в таблицу", {{"Column1", each Text.AfterDelimiter(_, "?", {0, RelativePosition.FromEnd}), type text}}),
    #"Разделить столбец по разделителю" = Table.SplitColumn(#"Извлеченный текст после разделителя", "Column1", Splitter.SplitTextByDelimiter("=", QuoteStyle.Csv), {"Column1.1", "Column1.2"}),
    #"Измененный тип" = Table.TransformColumnTypes(#"Разделить столбец по разделителю",{{"Column1.1", type text}, {"Column1.2", type text}}),
    #"Строки с примененным фильтром" = Table.SelectRows(#"Измененный тип", each ([Column1.2] <> null and [Column1.2] <> "") and ([Column1.1] <> "date1" and [Column1.1] <> "date2" and [Column1.1] <> "id")),
    #"Замененное значение" = Table.ReplaceValue(#"Строки с примененным фильтром","%3A",":",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение1" = Table.ReplaceValue(#"Замененное значение","%3C","<",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение2" = Table.ReplaceValue(#"Замененное значение1","%3E",">",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение3" = Table.ReplaceValue(#"Замененное значение2","%2C",",",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение4" = Table.ReplaceValue(#"Замененное значение3","%20"," ",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение5" = Table.ReplaceValue(#"Замененное значение4","%5B","[",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение6" = Table.ReplaceValue(#"Замененное значение5","%5D","]",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение7" = Table.ReplaceValue(#"Замененное значение6","%3D","=",Replacer.ReplaceText,{"Column1.2"}),
    #"Замененное значение8" = Table.ReplaceValue(#"Замененное значение7","%22","""",Replacer.ReplaceText,{"Column1.2"}),
    #"Сведенный столбец" = Table.Pivot(#"Замененное значение8", List.Distinct(#"Замененное значение8"[Column1.1]), "Column1.1", "Column1.2"){0}
in #"Сведенный столбец";
   


dateFunc= (dat)=>
       if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
       else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
       else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
       else dat;




// Data Source Kind description
AppMetrica = [
    TestConnection = (dataSourcePath) => 
        { 
        "AppMetrica.Stat",
        Json.Document(dataSourcePath)[id],
        Json.Document(dataSourcePath)[start],
        Json.Document(dataSourcePath)[end],
        Json.Document(dataSourcePath)[custom]?,
        Json.Document(dataSourcePath)[metrics]?,
        Json.Document(dataSourcePath)[dimensions]?
        },
    Authentication = [
        
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
         //  Refresh=Refresh,
         // Logout=Logout,
            Label = "Log In"
            ]
    ],
    Label = "AppMetrica Connection"
];

// https://oauth.yandex.ru/authorize?response_type=code&client_id=5d5a116c2b194f838d286369ddd15388

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://oauth.yandex.ru/authorize?" & Uri.BuildQueryString([
            response_type="code",
            client_id="5d5a116c2b194f838d286369ddd15388",
            state = state,
            force_confirm="yes",
            redirect_uri = redirect_uri
            ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = "Hello"
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Text.From(Parts[code]));
        
    




TokenMethod = (code ) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/token", [IsRetry=false, ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type ="authorization_code",
                client_id="5d5a116c2b194f838d286369ddd15388",
                code = code,
                client_secret = "92e1538bc9f44705bca81c32a720cadb",
                redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        Body;



Refresh = (resourceUrl, refresh_token) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/token", [IsRetry=false, ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type ="refresh_token",
                refresh_token =refresh_token,
                client_id="5d5a116c2b194f838d286369ddd15388",
                client_secret = "92e1538bc9f44705bca81c32a720cadb",
                redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        Body;



Logout = (token ) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/revoke_token", [ ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                access_token=if token = null then "" else token,
                client_id="5d5a116c2b194f838d286369ddd15388",
                client_secret = "92e1538bc9f44705bca81c32a720cadb"
              //  device_id="0",
                //redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        if Body[status]?="ok" then Body else [status="ne ok"];





// Data Source UI publishing description
AppMetrica.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "AppMetrica Connector", "Help" },
    LearnMoreUrl = "https://www.youtube.com/channel/UCqSLNYLN_3mf6nA1Xf7fu1g",
    SourceImage = AppMetrica.Icons,
    SourceTypeImage = AppMetrica.Icons
];

AppMetrica.Icons = [
    Icon16 = { Extension.Contents("AppMetrica16.png"), Extension.Contents("AppMetrica20.png"), Extension.Contents("AppMetrica24.png"), Extension.Contents("AppMetrica32.png") },
    Icon32 = { Extension.Contents("AppMetrica32.png"), Extension.Contents("AppMetrica40.png"), Extension.Contents("AppMetrica48.png"), Extension.Contents("AppMetrica64.png") }
];
