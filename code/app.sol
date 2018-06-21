pragma solidity ^0.4.22;

/**
 * @title Journey
 *
 * Contract responsible for all the aspects of a working day, specifying the
 * employee's obligations to the company
 */
contract Journey {
    /// Shows if an employee is working (IN) or not (OUT)
    enum StateType { IN, OUT }

    /// all the clauses in the working day contract
    struct WorkerJourney {
        StateType state; //!< State of an employee (in or out)
        uint realMinutes; //!< Minimum working time for an employee (in minutes)
        uint computedMinutes; //!< Time worked by an employee (in minutes) with the multiplier applied
        uint hourBank; //!< Every overtime in the work goes to hour bank
        uint enteredAt; //!< Time that the employee entered
    }

    uint private clk; //!< Demands the passage of time through the use of the scheduler

    address private boss; //!< User that have super privileges on the system

    address private workMultiplierAddr; //!< Address of the contract that is responsible for managing multipliers

    address private workerContractAddr; //!< Address of the contract that is responsible for managing workers contracts

    /// Definition of scheduler, this will check the number of blocks on
    /// blockchain to sync with time worked by an employee
    ///
    /// @see Ethereum Alarm Clock (http://docs.ethereum-alarm-clock.com/en/latest/)
    SchedulerInterface constant scheduler = SchedulerInterface(0x6C8f2A135f6ed072DE4503Bd7C4999a1a17F824B);

    /// Mapping employee's address to employee's record
    mapping(address => WorkerJourney) public records;

    /**
     * @dev Defines the boss and starts the working day's contract
     */
    constructor(address _workMultiplierAddr, address _workerContractAddr) public {
        boss = msg.sender;
        workMultiplierAddr = _workMultiplierAddr;
        workerContractAddr = _workerContractAddr;
        clk = 0;

        uint lockedUntil = block.number + 5;
        // TODO: Verificar constantes aleatórias que não sei se devo mexer:
        uint[3] memory uintArgs = [
            200000,      // the amount of gas that will be sent with the txn.
            0,           // the amount of ether (in wei) that will be sent with the txn
            lockedUntil // the first block number on which the transaction can be executed.
        ];
        // TODO: Passar msg.sender atual para a transação agendada
        scheduler.scheduleTransaction(
            address(this),  // The address that the transaction will be sent to.
            "",    // The call data that will be sent with the transaction.
            4,            // The number of blocks this will be executable.
            uintArgs       // The tree args defined above
        );
    }

    /**
     * @dev This function records when an employee starts their work day and
     * set necessary constants to the scheduler. This scheduler will sync the
     * time worked by an employee
     */
    function enterRecord() public {
        // Validar alguma coisa aqui?
        require(records[msg.sender].state == StateType.OUT, "Worker should be OUT to be able to enter");
        records[msg.sender].state = StateType.IN;
        records[msg.sender].enteredAt = clk;
    }

    /**
     * @dev Defines the behaviour of the scheduler
     */
    function() public {
        clk++;

        // Fazer schedule para incrementar workMinutes a cada 5 blocos
        // Bloqueia por 5 blocos:
        uint lockedUntil = block.number + 5;
        uint[3] memory uintArgs = [
            200000,      // the amount of gas that will be sent with the txn.
            0,           // the amount of ether (in wei) that will be sent with the txn
            lockedUntil // the first block number on which the transaction can be executed.
        ];
        // TODO: Passar msg.sender atual para a transação agendada
        scheduler.scheduleTransaction(
            address(this),  // The address that the transaction will be sent to.
            "",             // The call data that will be sent with the transaction.
            4,            // The number of blocks this will be executable.
            uintArgs       // The tree args defined above
        );
    }

    // Precisa ser chamado em algum momento....talvez no final do mês ou algo
    // assim
    /**
     * @dev This function will compute all the time worked by an employee,
     * including overtime, and make payment accordingly, including bonuses for
     * overtime.
     */
    function payWorker(address worker) public returns (uint result)   {
        require(boss == msg.sender, "Only boss can do payment");
        require(records[worker].state == StateType.OUT, "Worker should be out to do payment");
        WorkerContract workContract = WorkerContract(workerContractAddr);
        result = records[worker].computedMinutes * workContract.getHourValue(worker);
        records[worker].realMinutes = 0;
    }

    // Registra a saida do funcionário
    /**
     * @dev This function records when an employee finishes its work day
     */
    function leftRecord() public {
        require(records[msg.sender].state == StateType.IN, "Worker should be IN to be able to left");
        records[msg.sender].state = StateType.OUT;

        uint dif = clk - records[msg.sender].enteredAt;

        WorkMultiplier workMultiplier = WorkMultiplier(workMultiplierAddr);

        for (uint i = 0; i < dif; i++) {
            records[msg.sender].realMinutes = records[msg.sender].realMinutes+1;
            uint[2] memory multiplier = workMultiplier.getMultiplier(msg.sender, records[msg.sender].realMinutes);
            for (uint j = records[msg.sender].realMinutes; j <= multiplier[0]; j++) {
                records[msg.sender].computedMinutes = records[msg.sender].computedMinutes + multiplier[1];
            }
        }

    }
}

/**
 * @title WorkerContract
 *
 * Contract responsible for all the aspects of a employee's contract, specifying
 * the relationship between the company and the worker
 *
 */
contract WorkerContract {
    /// Defines the characteristics of an employee
    struct Worker {
        string name; //!< Employee's name
        string cpf; //!< Employee's cpf ("natural persons register" or "cadastro
                // de pessoas físicas", in portuguese)
        uint hour_value; //!< How much an employee earns per hour
        bool isRegistered; //!< A boolean to allow us to detect if the register
                // is valid
    }

    /// Mapping employee's address to employee itself
    mapping(address => Worker) private workers;

    address private boss; //!< User that have super privileges on the system

    /**
     * @dev Defines the boss and starts the worker's contract
     */
    constructor() public {
        boss = msg.sender;
    }

    /**
     * @dev Returns the hour-value from a specific employee
     * @param worker Unique value that defines an employee
     */
    function getHourValue(address worker) public view returns (uint) {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(workers[worker].isRegistered, "The worker does not exist, so it cannot be edited");
        return workers[worker].hour_value;
    }

    /**
     * @dev Defines an employee and stores it in the structure 'workers'
     * @param worker Unique value that defines an employee
     * @param name Employee's name
     * @param cpf Employee's cpf
     * @param hourValue Hour-Value specified for this employee
     */
    function createWorker(address worker, string name, string cpf, uint hourValue) public {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(bytes(name).length > 0, "A worker must have a name");
        require(bytes(cpf).length > 0, "A worker must have CPF");
        require(!workers[worker].isRegistered, "The worker already exists, so it cannot be created");
        workers[worker] = Worker({
            name: name,
            cpf: cpf,
            hour_value: hourValue,
            isRegistered: true
        });
    }

    /**
     * @dev Edits some of employee's properties from the records
     * @param worker Unique value that defines an employee
     * @param hourValue Hour-Value specified for this employee
     */
    function editWorker(address worker, uint hourValue) public {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(workers[worker].isRegistered, "The worker does not exist, so it cannot be edited");
        workers[worker].hour_value = hourValue;
    }

    /**
     * @dev Removes a worker from the records
     * @param worker Unique value that defines an employee
     */
    function removeWorker(address worker) public {
        require(msg.sender == boss, "Only the boss can remove workers");
        require(workers[worker].isRegistered, "The worker does not exist, so it cannot be removed");
        delete workers[worker];
    }
}

/**
 * @title WorkMultiplier
 *
 * Contract relative to the bonuses for an employee, if an employee works more
 * than the specified in their contract, a multiplier bonus will be applied in
 * its payment
 */
contract WorkMultiplier {

    /// Specification of the multiplier
    struct Multiplier {
        uint min; //!< A minimum multiplier that can be applied
        uint max; //!< Maximum multiplier that can be applied
        uint multiplier; //!< Multiplier value to be applied in a bonus
    }

    /// Mapping multipliers address to a multiplier array
    mapping(address => Multiplier[]) private multipliers;

    address private boss; //!< User that have super privileges on the system

    /**
     * @dev Defines the boss and starts the multiplier's contract
     */
    constructor() public {
        boss = msg.sender;
    }

    /**
     * @dev Add multiplier to a specific employee
     * @param worker Unique value that defines an employee
     * @param min Minimum multiplier that can be applied
     * @param max Maximum Value that can be applied
     * @param multiplier Multiplier value to be applied in a bonus
     */
    function addMultiplier(address worker, uint min, uint max, uint multiplier) public {
        require(msg.sender == boss, "Only the boss can add multipliers");
        multipliers[worker].push(Multiplier({
            min: min,
            max: max,
            multiplier: multiplier
        }));
    }

    /**
     * @dev Clears the multiplier relative to a specific employee
     * @param worker Unique value that defines an employee
     */
    function clearMultipliers(address worker) public {
        require(msg.sender == boss, "Only the boss can remove multipliers");
        delete multipliers[worker];
    }

    /**
     * @dev Applies the respective multiplier on the employee's payment
     * @param worker Unique value that defines an employee
     * @param realMinutes Overtime minutes that will be applied in the payment
     */
    function getMultiplier(address worker, uint realMinutes) public view returns (uint[2])  {
        for (uint i = 0; i < multipliers[worker].length; i++) {
            if (multipliers[worker][i].min >= realMinutes && multipliers[worker][i].max <= realMinutes) {
                return [multipliers[worker][i].max, multipliers[worker][i].multiplier];
            }
        }
        revert("Multiplier not found");
    }
}

/**
 * @title SchedulerInterface
 *
 * Abstract contract for the scheduler
 */
contract SchedulerInterface {
    /**
     * @dev Abstract contract for the Ethereum Alarm Clock
     * @param toAddress Unique value to be applied
     * @param callData All the data needed in the alarm
     * @param windowSize The number of blocks this will be executable.
     * @param uintArgs Extra arguments for the alarm:
     *      - uintArgs[0] callGas
     *      - uintArgs[1] callValue
     *      - uintArgs[2] windowStart
     */
    function scheduleTransaction(address toAddress,
                                 bytes callData,
                                 uint8 windowSize,
                                 uint[3] uintArgs) public returns (address);
}
