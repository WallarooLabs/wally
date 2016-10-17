use @create_askprice_1[DataP]()
use @create_askprice_2[DataP]()
use @compareObjects[Bool](ap1: DataP, ap2: DataP)

actor Main
  new create(env: Env) =>
    let askprice_1 = CPPData(CPPManagedObject(@create_askprice_1()))
    let askprice_2 = CPPData(CPPManagedObject(@create_askprice_2()))

    let s_askprice_1 = askprice_1.serialize()
    let s_askprice_2 = askprice_2.serialize()

    let d_askprice_1 = CPPDataDeserialize(s_askprice_1)
    let d_askprice_2 = CPPDataDeserialize(s_askprice_2)

    env.out.write("askprice_1: ")
    if (@compareObjects(askprice_1.obj(), d_askprice_1.obj())) then
      env.out.print("SAME!")
    else
      env.out.print("DIFFERENT!")
    end

    env.out.write("askprice_2: ")
    if (@compareObjects(askprice_2.obj(), d_askprice_2.obj())) then
      env.out.print("SAME!")
    else
      env.out.print("DIFFERENT!")
    end
