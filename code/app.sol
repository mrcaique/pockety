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

    address private boss; //!< User that have super privileges on the system

    address private workMultiplierAddr; //!< Address of the contract that is responsible for managing multipliers

    address private workerContractAddr; //!< Address of the contract that is responsible for managing workers contracts

    /// Mapping employee's address to employee's record
    mapping(address => WorkerJourney) public records;

    /**
     * @dev Defines the boss and starts the working day's contract
     */
    constructor(address _workMultiplierAddr, address _workerContractAddr) public {
        boss = msg.sender;
        workMultiplierAddr = _workMultiplierAddr;
        workerContractAddr = _workerContractAddr;
    }

    /**
     * @dev This function records when an employee starts their work day and
     * set necessary constants to the scheduler. This scheduler will sync the
     * time worked by an employee
     */
    function enterRecord() public {
        require(records[msg.sender].state == StateType.OUT, "Worker should be OUT to be able to enter");
        records[msg.sender].state = StateType.IN;
        records[msg.sender].enteredAt = now;
    }

    /**
     * @dev This function will compute all the time worked by an employee,
     * including overtime, and make payment accordingly, including bonuses for
     * overtime.
     */
    function payWorker(address worker) public  {
        require(boss == msg.sender, "Only boss can do payment");
        require(records[worker].state == StateType.OUT, "Worker should be out to do payment");
        WorkerContract workContract = WorkerContract(workerContractAddr);
        uint value = records[worker].computedMinutes * workContract.getHourValue(worker);
        worker.transfer(value);
        records[worker].realMinutes = 0;
    }

    // Registra a saida do funcionário
    /**
     * @dev This function records when an employee finishes its work day
     */
    function leftRecord() public {
        require(records[msg.sender].state == StateType.IN, "Worker should be IN to be able to left");
        records[msg.sender].state = StateType.OUT;

        uint dif = now - records[msg.sender].enteredAt;

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
     * @param addr Address of the employee
     */
    function getHourValue(address addr) public view returns (uint) {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(workers[addr].isRegistered, "The worker does not exist, so it cannot be edited");
        return workers[addr].hour_value;
    }

    /**
     * @dev Defines an employee and stores it in the structure 'workers'
     * @param addr Address of the employee
     * @param hourValue Hour-Value specified for this employee
     */
    function createWorker(address addr, uint hourValue) public {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(!workers[addr].isRegistered, "The worker already exists, so it cannot be created");
        workers[addr] = Worker({
            hour_value: hourValue,
            isRegistered: true
        });
    }

    /**
     * @dev Edits some of employee's properties from the records
     * @param addr Address of the employee
     * @param hourValue Hour-Value specified for this employee
     */
    function editWorker(address addr, uint hourValue) public {
        require(msg.sender == boss, "Only the boss can edit workers");
        require(workers[addr].isRegistered, "The worker does not exist, so it cannot be edited");
        workers[addr].hour_value = hourValue;
    }

    /**
     * @dev Removes a worker from the records
     * @param addr Address of the employee
     */
    function removeWorker(address addr) public {
        require(msg.sender == boss, "Only the boss can remove workers");
        require(workers[addr].isRegistered, "The worker does not exist, so it cannot be removed");
        delete workers[addr];
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
