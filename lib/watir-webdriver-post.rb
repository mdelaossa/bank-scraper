require 'watir-webdriver'

module Watir
  class Browser
    def post(url, params)
      script = <<-SCRIPT
      function post(path, params) {
        method = "post";

        var form = document.createElement("form");
        form.setAttribute("method", method);
        form.setAttribute("action", path);

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
        form.submit();
      }

      post(arguments[0], arguments[1]);
      return arguments[1]
      SCRIPT

      args = execute_script script, url, params
      wait
      args
    end
  end
end
