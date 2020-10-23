#r "Newtonsoft.Json"

using System.Net;
using System.Text;
using Newtonsoft.Json;
using  Newtonsoft.Json.Linq;

public static async Task<HttpResponseMessage> Run(HttpRequest req, ILogger log)
{
    log.LogInformation("GetGroupMembership");

    string objectId = req.Query["objectId"];
    string tenantId = req.Query["tenantId"];

    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JsonConvert.DeserializeObject(requestBody);
    objectId = objectId ?? data?.objectId;
    tenantId = tenantId ?? data?.tenantId;

    log.LogInformation("Params: objectId=" + objectId + ", tenantId: " + tenantId);

    // if you have enabled Client Cert auth, we check the cert
    var cert = req.HttpContext.Connection.ClientCertificate;
    log.LogInformation($"Incoming cert: {cert}");
    if(cert != null ) { 
        var b2cCertSubject = System.Environment.GetEnvironmentVariable( $"B2C_{tenantId}_CertSubject"); //
        var b2cCertThumbprint = System.Environment.GetEnvironmentVariable($"B2C_{tenantId}_CertThumbprint");
        if ( !( cert.Subject.Equals(b2cCertSubject) && cert.Thumbprint.Equals(b2cCertThumbprint) ) ) {
            var respContent = new { version = "1.0.0", status = (int)HttpStatusCode.BadRequest, 
                                    userMessage = "Technical error - cert..."};
            var json = JsonConvert.SerializeObject(respContent);
            log.LogInformation(json);
            return new HttpResponseMessage(HttpStatusCode.Conflict) {
                            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
            };
        }
    }

    // This Azure Function can serve many B2C tenants, so config is stored per tenantid
    var b2cClientId = System.Environment.GetEnvironmentVariable($"B2C_{tenantId}_ClientId"); //
    var b2cClientSecret = System.Environment.GetEnvironmentVariable($"B2C_{tenantId}_ClientSecret");

    // acquire access token via client creds
    HttpClient client = new HttpClient();
    var url = $"https://login.microsoftonline.com/{tenantId}/oauth2/token?api-version=1.0";
    var dict= new Dictionary<string, string>();
    dict.Add("grant_type", "client_credentials");
    dict.Add("client_id", b2cClientId);
    dict.Add("client_secret", b2cClientSecret);
    dict.Add("resource", "https://graph.microsoft.com");
    dict.Add("scope", "User.Read.All");

    log.LogInformation(url);
    HttpResponseMessage res = client.PostAsync(url, new FormUrlEncodedContent(dict)).Result;
    var contents = await res.Content.ReadAsStringAsync();
    client.Dispose();
    log.LogInformation("HttpStatusCode=" + res.StatusCode.ToString());

    // return either good message that REST API expects or 409 conflict    
    if ( res.StatusCode != HttpStatusCode.OK ) {
        var respContent = new { version = "1.0.0", status = (int)HttpStatusCode.BadRequest, 
                                userMessage = "Technical error..."};
        var json = JsonConvert.SerializeObject(respContent);
        log.LogInformation(json);
        return new HttpResponseMessage(HttpStatusCode.Conflict) {
                        Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        };
    }

    var accessToken = JObject.Parse(contents)["access_token"];
    log.LogInformation(accessToken.ToString());
    client = new HttpClient();
    client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken.ToString());
    url = $"https://graph.microsoft.com/v1.0/users/{objectId}/memberOf?$select=id,displayName";

    log.LogInformation(url);
    var groupsList = new List<string>();
    res = await client.GetAsync(url);
    log.LogInformation("HttpStatusCode=" + res.StatusCode.ToString());
    if(res.IsSuccessStatusCode)
    {
        var respData = await res.Content.ReadAsStringAsync();
        var groupArray = (JArray)JObject.Parse(respData)["value"];
        foreach (JObject g in groupArray) {
            var name = g["displayName"].Value<string>();
            groupsList.Add(name);
        }    
    }
    client.Dispose();
    var jsonToReturn = JsonConvert.SerializeObject( new { groups = groupsList } );
    log.LogInformation(jsonToReturn);
    return new HttpResponseMessage(HttpStatusCode.OK) {
            Content = new StringContent(jsonToReturn, System.Text.Encoding.UTF8, "application/json")
        };
}
