require 'watir-webdriver'

module Watir
  class Browser
    def post(url, params, callback = nil)
      script = %q[
        function watirPost(path, params, callback) {
          method = "post";

          var form = document.createElement("form");
          form.setAttribute("method", method);
          form.setAttribute("action", path);
          form.setAttribute("name", "WatirPostForm");

          for(var key in params) {
              if(params.hasOwnProperty(key)) {
                  var hiddenField = document.createElement("input");
                  hiddenField.setAttribute("type", "hidden");
                  hiddenField.setAttribute("name", key);
                  hiddenField.setAttribute("value", params[key]);

                  form.appendChild(hiddenField);
               }
          }

          document.body.appendChild(form);

          if (typeof callback === "function") {
            callback(form);
          } else {
            form.submit();
          }
        }

        watirPost(arguments[0], arguments[1], eval("("+arguments[2]+")"));
      ]
      execute_script script, url, params, callback
      wait
    end
  end
end
