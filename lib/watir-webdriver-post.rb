require 'watir-webdriver'

module Watir
  class Browser
    def post(url, params, callback = nil)
      script = <<-SCRIPT
      function post(path, params, callback) {
        method = "post";

        var form = document.createElement("form");
        form.setAttribute("method", method);
        form.setAttribute("action", path);
        form.setAttribute("name", 'WatirPostForm');

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

        if (callback) {
          callback()
        } else {
          form.submit();
        }
      }

      post(arguments[0], arguments[1], arguments[2]);
      SCRIPT

      execute_script script, url, params, callback
      wait
    end
  end
end
