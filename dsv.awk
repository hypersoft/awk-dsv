    #!/bin/awk -f
    #
    ###############################################################
    #
    # ZERO LIABILITY OR WARRANTY LICENSE YOU MAY NOT OWN ANY
    # COPYRIGHT TO THIS SOFTWARE OR DATA FORMAT IMPOSED HEREIN 
    # THE AUTHOR PLACES IT IN THE PUBLIC DOMAIN FOR ALL USES 
    # PUBLIC AND PRIVATE THE AUTHOR ASKS THAT YOU DO NOT REMOVE
    # THE CREDIT OR LICENSE MATERIAL FROM THIS DOCUMENT.
    #
    ###############################################################
    #
    # Special thanks to Jonathan Leffler, whose wisdom, and 
    # knowledge defined the output logic of this script.
    #
    # Special thanks to GNU.org for the base conversion routines.
    #
    # Credits and recognition to the original Author:
    # Triston J. Taylor whose countless hours of experience,
    # research and rationalization have provided us with a
    # more portable standard for parsing DSV records.
    #
    ###############################################################
    #
    # This script accepts and parses a single line of DSV input
    # from <STDIN>.
    #
    # Record fields are seperated by command line varibale
    # 'iDelimiter' the default value is comma.
    #
    # Ouput is seperated by command line variable 'oDelimiter' 
    # the default value is line feed.
    #
    # To learn more about this tool visit StackOverflow.com:
    #
    # http://stackoverflow.com/questions/10578119/
    #
    # You will find there a wealth of information on its
    # standards and development track.
    #
    ###############################################################

    function NextSymbol() {

        strIndex++;
        symbol = substr(input, strIndex, 1);

        return (strIndex < parseExtent);
        
    }

    function Accept(query) {
        
        #print "query: " query " symbol: " symbol
        if ( symbol == query ) {
            #print "matched!"        
            return NextSymbol();         
        }
        
        return 0;
        
    }

    function Expect(query) {

        # special case: empty query && symbol...
        if ( query == nothing && symbol == nothing ) return 1;

        # case: else
        if ( Accept(query) ) return 1;
        
        msg = "dsv parse error: expected '" query "': found '" symbol "'";
        print msg > "/dev/stderr";
        
        return 0;
        
    }

    function PushData() {
        
        field[fieldIndex++] = fieldData;
        fieldData = nothing;
        
    }

    function Quote() {

        while ( symbol != quote && symbol != nothing ) {
            fieldData = fieldData symbol;
            NextSymbol();
        }
        
        Expect(quote);
        
    }

    function GetOctalChar() {

        qOctalValue = substr(input, strIndex+1, 3);
        
        # This isn't really correct but its the only way
        # to express 0-255. On unicode systems it won't
        # matter anyway so we don't restrict the value
        # any further than length validation.
        
        if ( qOctalValue ~ /^[0-7]{3}$/ ) {
        
            # convert octal to decimal so we can print the
            # desired character in POSIX awks...
            
            n = length(qOctalValue)
            ret = 0
            for (i = 1; i <= n; i++) {
                c = substr(qOctalValue, i, 1)
                if ((k = index("01234567", c)) > 0)
                k-- # adjust for 1-basing in awk
                ret = ret * 8 + k
            }
            
            strIndex+=3;
            return sprintf("%c", ret);
            
            # and people ask why posix gets me all upset..
            # Special thanks to gnu.org for this contrib..
            
        }
        
        return sprintf("\0"); # if it wasn't 3 digit octal just use zero
        
    }
                 
    function GetHexChar(qHexValue) {
        
        rHexValue = HexToDecimal(qHexValue);
        rHexLength = length(qHexValue);
        
        if ( rHexLength ) {
                
            strIndex += rHexLength;
            return sprintf("%c", rHexValue);
                    
        }
        
        # accept no non-sense!
        printf("dsv parse error: expected " rHexLength) > "/dev/stderr";
        printf("-digit hex value: found '" qHexValue "'\n") > "/dev/stderr";
        
    }
      
    function HexToDecimal(hexValue) {

        if ( hexValue ~ /^[[:xdigit:]]+$/ ) {
        
            # convert hex to decimal so we can print the
            # desired character in POSIX awks...
            
            n = length(hexValue)
            ret = 0
            for (i = 1; i <= n; i++) {
            
                c = substr(hexValue, i, 1)
                c = tolower(c)
                
                if ((k = index("0123456789", c)) > 0)
                    k-- # adjust for 1-basing in awk
                else if ((k = index("abcdef", c)) > 0)
                    k += 9

                ret = ret * 16 + k
            }
            
            return ret;
            
            # and people ask why posix gets me all upset..
            # Special thanks to gnu.org for this contrib..
            
        }
        
        return nothing;
        
    }
      
    function BackSlash() {

        # This could be optimized with some constants.
        # but we generate the data here to assist in
        # translation to other programming languages.
        
        if (symbol == iDelimiter) { # separator precedes all sequences
            fieldData = fieldData symbol;
        } else if (symbol == "a") { # alert
            fieldData = sprintf("%s\a", fieldData);
        } else if (symbol == "b") { # backspace
            fieldData = sprintf("%s\b", fieldData);
        } else if (symbol == "f") { # form feed
            fieldData = sprintf("%s\f", fieldData);
        } else if (symbol == "n") { # line feed
            fieldData = sprintf("%s\n", fieldData);
        } else if (symbol == "r") { # carriage return
            fieldData = sprintf("%s\r", fieldData);
        } else if (symbol == "t") { # horizontal tab
            fieldData = sprintf("%s\t", fieldData);
        } else if (symbol == "v") { # vertical tab
            fieldData = sprintf("%s\v", fieldData);
        } else if (symbol == "0") { # null or 3-digit octal character
            fieldData = fieldData GetOctalChar();
        } else if (symbol == "x") { # 2-digit hexadecimal character 
            fieldData = fieldData GetHexChar( substr(input, strIndex+1, 2) );
        } else if (symbol == "u") { # 4-digit hexadecimal character 
            fieldData = fieldData GetHexChar( substr(input, strIndex+1, 4) );
        } else if (symbol == "U") { # 8-digit hexadecimal character 
            fieldData = fieldData GetHexChar( substr(input, strIndex+1, 8) );
        } else { # symbol didn't match the "interpreted escape scheme"
            fieldData = fieldData symbol; # just concatenate the symbol
        }

        NextSymbol();
        
    }

    function Line() {

        if ( Accept(quote) ) {
            Quote();
            Line();
        }
        
        if ( Accept(backslash) ) {
            BackSlash();
            Line();        
        }
        
        if ( Accept(iDelimiter) ) {
            PushData();
            Line();
        }
        
        if ( symbol != nothing ) {
            fieldData = fieldData symbol;
            NextSymbol();
            Line();
        } else if ( fieldData != nothing ) PushData();
        
    }

    BEGIN {

        # State Variables
        symbol = ""; fieldData = ""; strIndex = 0; fieldIndex = 0;
        
        # Output Variables
        field[itemIndex] = "";

        # Control Variables
        parseExtent = 0;

        # Formatting Variables (optionally set on invocation line)
        if ( iDelimiter != "" ) {
            # the algorithm in place does not support multi-character delimiter
            if ( length(iDelimiter) > 1 ) { # we have a problem
                msg = "dsv parse: init error: multi-character delimiter detected:";
                printf("%s '%s'", msg, iDelimiter);
                exit 1;
            }
        } else {
            iDelimiter = ",";
        }
        if ( oDelimiter == "" ) oDelimiter = "\n";
        
        # Symbol Classes
        nothing = "";
        quote = "\"";
        backslash = "\\";
        
        getline input;
        
        parseExtent = (length(input) + 2);
        
        # parseExtent exceeds length because the loop would terminate
        # before parsing was complete otherwise.
        
        NextSymbol();
        Line();
        Expect(nothing);
        
    }

    END {

        if (fieldIndex) {
        
            fieldIndex--;
            
            for (i = 0; i < fieldIndex; i++)
            {
                 printf("%s", field[i] oDelimiter);
            }

            print field[i];
            
        } 
          
    }
