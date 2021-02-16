using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace GraphApp
{
    class Program
    {
        private string graphEndpoint="https://graph.microsoft.com/beta";
        private string access_token = "";
        string tenantId = "";
        string b2cClientId = "";
        string b2cClientSecret = "";

        static void Main(string[] args)
        {
            Program p = new Program();
            p.Go(args);
        }
        public void Go(string[] args)
        {
            tenantId = args[0];                 // yourtenant.onmicrosoft.com
            b2cClientId = args[1];              // B2C AppId 
            b2cClientSecret = args[2];          // B2C App secret

            if (!AcquireAccessToken(tenantId, b2cClientId, b2cClientSecret))
                    return;

            string appId = null; string appObjectId = null;
            GetAppIdByName("b2c-extensions-app", out appObjectId, out appId );

            string LoyalityNumberAttrName = GetExtensionAttribute(appObjectId, appId, "LoyalityNumber");
            if ( string.IsNullOrEmpty(LoyalityNumberAttrName))
                LoyalityNumberAttrName = NewExtensionAttribute(appObjectId, "LoyalityNumber", "String" );
            
            string MembershipStatusAttrName = GetExtensionAttribute(appObjectId, appId, "MembershipStatus");
            if ( string.IsNullOrEmpty(MembershipStatusAttrName))
                MembershipStatusAttrName = NewExtensionAttribute(appObjectId, "MembershipStatus", "String");


            string email = "alice@contoso.com";
            string mobilePhone = "+14255551212";
            string displayName = "Alice Contoso";
            var extraAtts = new Dictionary<string, string>
            {
                { "mail", email },
                { "surname", "Contoso" },
                { "givenName", "Alice" },
                { LoyalityNumberAttrName, "123456789" },
                { MembershipStatusAttrName, "Gold" }
            };
            string userObjectId = "";
            JObject user = GetUser(email);
            if (user == null)
            {
                userObjectId = NewUser(email, "SuperSecretPassword", displayName, mobilePhone, extraAtts);
            }
            else
            {
                userObjectId = user["id"].ToString();
                user[LoyalityNumberAttrName] = "123456789";
                user[VirtualCityTenantNameAttrName] = "Gold";
                UpdateUser(userObjectId, user);
            }

            // if you want to be able to use the mobilePhone to send OTP during MFA (or signin via OTP), you need to do this
            JObject strongAuth = GetUserStrongAuthPhoneNumber(userObjectId);
            if ( strongAuth == null )
            {
                SetUserStrongAuthPhoneNumber(userObjectId, mobilePhone);
            }

            string groupObjectId = "";
            JObject group = GetGroup("SalesAdmin");
            if ( group == null )
            {
                groupObjectId = NewGroup("SalesAdmin");
            } 
            else
            {
                groupObjectId = group["id"].ToString();
            }
            if ( !IsUserGroupMember( userObjectId, groupObjectId ) )
            {
                NewGroupMember(groupObjectId, userObjectId);
            }

        }
        /// <summary>
        /// Get an Access Token that we can use for the Graph API calls via client_credentials flow.
        /// The clientId needs to be given the approriate permissions or the token will not work
        /// </summary>
        /// <param name="tenantId"></param>
        /// <param name="b2cClientId"></param>
        /// <param name="b2cClientSecret"></param>
        /// <returns></returns>
        private bool AcquireAccessToken(string tenantId, string b2cClientId, string b2cClientSecret)
        {
            var dict = new Dictionary<string, string>
            {
                { "grant_type", "client_credentials" },
                { "client_id", b2cClientId },
                { "client_secret", b2cClientSecret },
                { "resource", "https://graph.microsoft.com" },
                { "scope", "Application.Read.All User.ReadWrite.All Group.ReadWrite.All UserAuthenticationMethod.ReadWrite.All" }
            };
            string contents = null;
            using (HttpClient client = new HttpClient())
            {
                HttpResponseMessage res = client.PostAsync($"https://login.microsoftonline.com/{tenantId}/oauth2/token?api-version=1.0", new FormUrlEncodedContent(dict)).Result;
                contents = res.Content.ReadAsStringAsync().Result;
                if (res.StatusCode != HttpStatusCode.OK)
                {
                    Console.WriteLine(contents);
                    return false;
                }
            }
            access_token = JObject.Parse(contents)["access_token"].ToString();
            return true;
        }
        /// <summary>
        /// Get the app "b2c-extensions-app"
        /// </summary>
        /// <param name="appName"></param>
        /// <returns></returns>
        private bool GetAppIdByName( string appName, out string objectId, out string appId )
        {
            objectId = null;
            appId = null;
            var result = HttpGet($"applications?$filter=startswith(displayName,'{appName}')");
            if (result == null)
                return false;
            var json = JObject.Parse( result );
            JArray values = (JArray)json["value"];
            if (values.Count == 0)
                 return false;
            JObject app = (JObject)values[0];
            objectId = app["id"].ToString();
            appId = app["appId"].ToString();
            return true;
        }

        /// <summary>
        /// Register a new extension attribute
        /// </summary>
        /// <param name="appId"></param>
        /// <param name="name"></param>
        /// <param name="dataType"></param>
        /// <returns></returns>
        private string NewExtensionAttribute( string appObjectId, string name, string dataType )
        {
            var body = new
            {
                name = name,
                dataType = dataType,
                targetObjects = new[] { "User" }
            };
            var result = HttpPost($"applications/{appObjectId}/extensionProperties", JsonConvert.SerializeObject(body));
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            return json["name"].ToString();
        }
        private string GetExtensionAttribute( string appObjectId, string appId, string name)
        {
            string fullName = string.Format("extension_{0}_{1}", appId.Replace("-", ""), name);
            var result = HttpGet($"applications/{appObjectId}/extensionProperties?$filter=name eq '{fullName}'");
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            JArray values = (JArray)json["value"];
            if (values.Count == 0)
                 return null;
            else return ((JObject)values[0])["name"].ToString();
        }

        /// <summary>
        /// Create a new group
        /// </summary>
        /// <param name="name"></param>
        /// <returns></returns>
        private string NewGroup(string name)
        {
            var body = new
            {
                description = name,
                displayName = name,
                mailNickname = name,
                securityEnabled = true,
                mailEnabled = false
            };
            var result = HttpPost( "groups", JsonConvert.SerializeObject(body));
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            return json["id"].ToString();
        }
        private JObject GetGroup( string displayName )
        {
            var result = HttpGet($"groups?$filter=displayName eq '{displayName}'");
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            JArray values = (JArray)json["value"];
            if (values.Count == 0)
                return null;
            else return (JObject)values[0];
        }
        /// <summary>
        /// Add a user as a group member
        /// </summary>
        /// <param name="groupObjectId"></param>
        /// <param name="userObjectId"></param>
        /// <returns></returns>
        private string NewGroupMember( string groupObjectId, string userObjectId )
        {
            JObject body = new JObject();
            body.Add("@odata.id", $"{graphEndpoint}/directoryObjects/{userObjectId}");
            var result = HttpPost($"groups/{groupObjectId}/members/$ref", JsonConvert.SerializeObject(body));
            return result;
        }

        private bool IsUserGroupMember( string userObjectId, string groupObjectId)
        {
            var result = HttpGet($"users/{userObjectId}/memberOf?$filter=id eq '{groupObjectId}'");
            if (result == null)
                return false;
            var json = JObject.Parse(result);
            JArray values = (JArray)json["value"];
            return true;
        }

        /// <summary>
        /// Create a new user
        /// </summary>
        /// <param name="email"></param>
        /// <param name="password"></param>
        /// <param name="displayName"></param>
        /// <param name="mobilePhone"></param>
        /// <param name="extraAttributes"></param>
        /// <returns></returns>
        private string NewUser(string email, string password, string displayName, string mobilePhone, Dictionary<string, string> extraAttributes )
        {
            var body = new
            {
                accountEnabled = true,
                creationType = "LocalAccount",
                displayName = displayName,
                mobilePhone = mobilePhone,
                passwordPolicies = "DisablePasswordExpiration",
                passwordProfile = new {
                    password = password,
                    forceChangePasswordNextSignIn = false
                },
                identities = new[] {
                    new { signInType = "phoneNumber", issuer = tenantId, issuerAssignedId = mobilePhone },
                    new { signInType = "emailAddress", issuer = tenantId, issuerAssignedId = email }
                }
            };

            JObject jsonObj = JObject.Parse(JsonConvert.SerializeObject(body));
            // add the extra attributes from the dictionary
            foreach (KeyValuePair<string, string> entry in extraAttributes)
            {
                jsonObj.Add(entry.Key, entry.Value);
            }
            var result = HttpPost( "users", JsonConvert.SerializeObject(jsonObj) );
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            return json["id"].ToString();
        }
        private bool UpdateUser( string userObjectId, JObject user)
        {
            var result = HttpPatch($"users/{userObjectId}", JsonConvert.SerializeObject(user));
            if (result == null)
                return false;
            return true;
        }
        private JObject GetUser( string email )
        {
            var result = HttpGet($"users?$filter=identities/any(x:x/issuerAssignedId eq '{email}' and c/issuer eq '{tenantId}')");
            if (result == null)
                return null;
            var json = JObject.Parse(result);
            JArray values = (JArray)json["value"];
            if (values.Count == 0)
                 return null;
            else return (JObject)values[0];
        }
        private string SetUserStrongAuthPhoneNumber(string userObjectId, string mobilePhone)
        {
            var body = new
            {
                phoneType = "mobile",
                phoneNumber = mobilePhone
            };
            var result = HttpPost($"users/{userObjectId}/authentication/phoneMethods", JsonConvert.SerializeObject(body));
            return result;
        }
        private JObject GetUserStrongAuthPhoneNumber(string userObjectId )
        {
            var result = HttpGet($"users/{userObjectId}/authentication/phoneMethods");
            if (result == null)
                return null;
            return JObject.Parse(result);
        }

        /// <summary>
        /// Helper method to do a HTTP GET to the Graph API Endpoint
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        private string HttpGet( string path )
        {
            string url = $"{graphEndpoint}/{path}";
            Console.WriteLine("GET {0}", url);
            string respData = null;
            using (HttpClient client = new HttpClient())
            {
                client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", access_token.ToString());
                var res = client.GetAsync(url).Result;
                if (res.IsSuccessStatusCode)
                {
                    respData = res.Content.ReadAsStringAsync().Result;
                }
            }
            return respData;
        }
        /// <summary>
        /// Helper method to do a HTTP POST to the Graph API Endpoint (Create objects in the directory)
        /// </summary>
        /// <param name="path"></param>
        /// <param name="body"></param>
        /// <returns></returns>
        private string HttpPost(string path, string body)
        {
            string url = $"{graphEndpoint}/{path}";
            Console.WriteLine("POST {0}\n{0}", url, body);
            string respData = null;
            using (HttpClient client = new HttpClient())
            {
                client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", access_token.ToString());
                HttpResponseMessage res = client.PostAsync(url, new StringContent(body, Encoding.UTF8, "application/json")).Result;
                respData = res.Content.ReadAsStringAsync().Result;
                if (!res.IsSuccessStatusCode)
                {
                    Console.WriteLine(respData);
                    return null;
                }
            }
            return respData;
        }
        /// <summary>
        /// Helper method to do a HTTP PATCH to the Graph API Endpoint (Update existing objects in the directory)
        /// </summary>
        /// <param name="path"></param>
        /// <param name="body"></param>
        /// <returns></returns>
        private string HttpPatch(string path, string body)
        {
            string url = $"{graphEndpoint}/{path}";
            Console.WriteLine("PATCH {0}\n{0}", url, body);
            string respData = null;
            using (HttpClient client = new HttpClient())
            {
                client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", access_token.ToString());
                HttpResponseMessage res = client.PatchAsync(url, new StringContent(body, Encoding.UTF8, "application/json")).Result;
                respData = res.Content.ReadAsStringAsync().Result;
                if (!res.IsSuccessStatusCode)
                {
                    Console.WriteLine(respData);
                    return null;
                }
            }
            return respData;
        }
    } // cls
} // ns
