package wallarooapi

//static char *getCommandlineArg(char **args, int idx) {
//  return args[idx];
//}
//
import "C"

var Args []string = make([]string, 0)

//export WallarooApiSetArgs
func WallarooApiSetArgs(argv **C.char, argc C.int) {
	for i := 0; i <= int(argc); i++ {
		Args = append(Args, C.GoString(C.getCommandlineArg(argv, C.int(i))))
	}
}
